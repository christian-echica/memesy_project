import json
import os
import uuid

import bcrypt
import boto3
from flask import Flask, g, jsonify, request

from shared.auth import issue_token, require_auth, revoke_token
from shared.cache import redis_client
from shared.db import get_conn, release_conn

app = Flask(__name__)

s3 = boto3.client("s3")
MEDIA_BUCKET = os.environ["MEDIA_BUCKET"]
CACHE_TTL = 300  # 5 min


# ── Health ────────────────────────────────────────────────────────────────────


@app.get("/health")
def health():
    return jsonify({"status": "ok", "service": "listing"})


# ── Auth ──────────────────────────────────────────────────────────────────────


@app.post("/api/auth/login")
def login():
    body = request.get_json(silent=True) or {}
    email = (body.get("email") or "").strip().lower()
    password = body.get("password") or ""

    if not email or not password:
        return jsonify({"error": "email and password required"}), 400

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, password_hash FROM users WHERE email = %s", (email,)
            )
            row = cur.fetchone()
    finally:
        release_conn(conn)

    if not row or not bcrypt.checkpw(password.encode(), row[1].encode()):
        return jsonify({"error": "Invalid credentials"}), 401

    token = issue_token(row[0])
    return jsonify({"token": token}), 200


@app.post("/api/auth/logout")
@require_auth
def logout():
    revoke_token(g.user_id)
    return jsonify({"message": "Logged out"}), 200


# ── Listings ──────────────────────────────────────────────────────────────────


@app.get("/api/listings")
def browse():
    cache_key = "listings:browse:page1"
    cached = redis_client.get(cache_key)
    if cached:
        return app.response_class(response=cached, mimetype="application/json")

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, title, price_cents, preview_url, attributes
                FROM listings
                WHERE active = true
                ORDER BY created_at DESC
                LIMIT 50
                """
            )
            rows = cur.fetchall()
    finally:
        release_conn(conn)

    listings = [
        {
            "id": r[0],
            "title": r[1],
            "price_cents": r[2],
            "preview_url": r[3],
            "attributes": r[4],
        }
        for r in rows
    ]
    payload = json.dumps(listings)
    redis_client.set(cache_key, payload, ex=CACHE_TTL)
    return app.response_class(response=payload, mimetype="application/json")


@app.get("/api/listings/<int:listing_id>")
def get_listing(listing_id: int):
    cache_key = f"listing:{listing_id}"
    cached = redis_client.get(cache_key)
    if cached:
        return app.response_class(response=cached, mimetype="application/json")

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, title, price_cents, preview_url, attributes, seller_id "
                "FROM listings WHERE id = %s AND active = true",
                (listing_id,),
            )
            row = cur.fetchone()
    finally:
        release_conn(conn)

    if not row:
        return jsonify({"error": "Not found"}), 404

    listing = {
        "id": row[0],
        "title": row[1],
        "price_cents": row[2],
        "preview_url": row[3],
        "attributes": row[4],
        "seller_id": row[5],
    }
    redis_client.set(cache_key, json.dumps(listing), ex=CACHE_TTL)
    return jsonify(listing)


@app.post("/api/listings")
@require_auth
def create_listing():
    title = request.form.get("title", "").strip()
    price_cents = request.form.get("price_cents")
    file = request.files.get("file")

    if not title or not price_cents or not file:
        return jsonify({"error": "title, price_cents, and file required"}), 400

    # Upload raw asset to private S3 bucket
    asset_key = f"assets/{uuid.uuid4()}/{file.filename}"
    s3.upload_fileobj(
        file,
        MEDIA_BUCKET,
        asset_key,
        ExtraArgs={"ContentType": file.content_type},
    )

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO listings (title, price_cents, asset_key, seller_id, active) "
                "VALUES (%s, %s, %s, %s, true) RETURNING id",
                (title, int(price_cents), asset_key, g.user_id),
            )
            listing_id = cur.fetchone()[0]
            conn.commit()
    finally:
        release_conn(conn)

    # Async: generate thumbnail, extract metadata, invalidate cache
    from celery_app import celery  # lazy import — Celery only in listing service

    celery.send_task("tasks.process_listing", args=[listing_id, asset_key, MEDIA_BUCKET])
    redis_client.delete("listings:browse:page1")

    return jsonify({"id": listing_id, "message": "Listing created"}), 201
