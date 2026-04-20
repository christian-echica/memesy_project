import json
import os

import boto3
import stripe
from flask import Flask, g, jsonify, request

from shared.auth import require_auth
from shared.db import get_conn, release_conn

app = Flask(__name__)

stripe.api_key = os.environ["STRIPE_SECRET_KEY"]
STRIPE_WEBHOOK_SECRET = os.environ["STRIPE_WEBHOOK_SECRET"]

sqs = boto3.client("sqs")
SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]


# ── Health ────────────────────────────────────────────────────────────────────


@app.get("/health")
def health():
    return jsonify({"status": "ok", "service": "payment"})


# ── Payment Intent ────────────────────────────────────────────────────────────


@app.post("/api/payment/intent")
@require_auth
def create_intent():
    """
    Creates a Stripe Payment Intent for a pending order.
    Client uses the returned client_secret to complete payment in-browser.
    """
    body = request.get_json(silent=True) or {}
    order_id = body.get("order_id")

    if not order_id:
        return jsonify({"error": "order_id required"}), 400

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT total_cents FROM orders WHERE id = %s AND buyer_id = %s AND status = 'pending'",
                (order_id, g.user_id),
            )
            row = cur.fetchone()
    finally:
        release_conn(conn)

    if not row:
        return jsonify({"error": "Order not found or already paid"}), 404

    intent = stripe.PaymentIntent.create(
        amount=row[0],
        currency="usd",
        metadata={"order_id": str(order_id), "buyer_id": str(g.user_id)},
        automatic_payment_methods={"enabled": True},
    )

    return jsonify({"client_secret": intent.client_secret})


# ── Stripe Webhook ────────────────────────────────────────────────────────────


@app.post("/api/webhook/stripe")
def stripe_webhook():
    """
    Stripe calls this after payment.  We validate the signature, mark the
    order paid, then publish to SQS so Lambda can generate signed URLs + email.
    """
    payload = request.get_data()
    sig = request.headers.get("Stripe-Signature", "")

    try:
        event = stripe.Webhook.construct_event(payload, sig, STRIPE_WEBHOOK_SECRET)
    except stripe.error.SignatureVerificationError:
        return jsonify({"error": "Invalid signature"}), 400

    if event["type"] == "payment_intent.succeeded":
        intent = event["data"]["object"]
        order_id = int(intent["metadata"]["order_id"])
        buyer_id = int(intent["metadata"]["buyer_id"])

        # Mark order as paid
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE orders SET status = 'paid', stripe_payment_intent_id = %s "
                    "WHERE id = %s",
                    (intent["id"], order_id),
                )
                # Fetch listing asset keys for this order
                cur.execute(
                    """
                    SELECT l.id, l.asset_key
                    FROM order_items oi
                    JOIN listings l ON l.id = oi.listing_id
                    WHERE oi.order_id = %s
                    """,
                    (order_id,),
                )
                items = [{"listing_id": r[0], "asset_key": r[1]} for r in cur.fetchall()]

                # Fetch buyer email for SES
                cur.execute("SELECT email FROM users WHERE id = %s", (buyer_id,))
                buyer_email = cur.fetchone()[0]
                conn.commit()
        finally:
            release_conn(conn)

        # Publish to SQS — Lambda generates signed URLs + emails buyer
        sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps({
                "order_id": order_id,
                "buyer_id": buyer_id,
                "buyer_email": buyer_email,
                "items": items,
            }),
        )

    return jsonify({"received": True}), 200
