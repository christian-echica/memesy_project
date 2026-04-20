from flask import Flask, g, jsonify, request

from shared.auth import require_auth
from shared.db import get_conn, release_conn

app = Flask(__name__)


# ── Health ────────────────────────────────────────────────────────────────────


@app.get("/health")
def health():
    return jsonify({"status": "ok", "service": "order"})


# ── Orders ────────────────────────────────────────────────────────────────────


@app.get("/api/orders")
@require_auth
def list_orders():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT o.id, o.total_cents, o.status, o.created_at,
                       array_agg(oi.listing_id) AS listing_ids
                FROM orders o
                JOIN order_items oi ON oi.order_id = o.id
                WHERE o.buyer_id = %s
                GROUP BY o.id
                ORDER BY o.created_at DESC
                """,
                (g.user_id,),
            )
            rows = cur.fetchall()
    finally:
        release_conn(conn)

    return jsonify([
        {
            "id": r[0],
            "total_cents": r[1],
            "status": r[2],
            "created_at": r[3].isoformat(),
            "listing_ids": r[4],
        }
        for r in rows
    ])


@app.get("/api/orders/<int:order_id>")
@require_auth
def get_order(order_id: int):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT o.id, o.total_cents, o.status, o.created_at,
                       oi.listing_id, oi.access_url
                FROM orders o
                JOIN order_items oi ON oi.order_id = o.id
                WHERE o.id = %s AND o.buyer_id = %s
                """,
                (order_id, g.user_id),
            )
            rows = cur.fetchall()
    finally:
        release_conn(conn)

    if not rows:
        return jsonify({"error": "Not found"}), 404

    return jsonify({
        "id": rows[0][0],
        "total_cents": rows[0][1],
        "status": rows[0][2],
        "created_at": rows[0][3].isoformat(),
        "items": [{"listing_id": r[4], "access_url": r[5]} for r in rows],
    })


@app.post("/api/orders")
@require_auth
def create_order():
    """Creates a pending order record. Payment service finalises it."""
    body = request.get_json(silent=True) or {}
    listing_ids: list[int] = body.get("listing_ids", [])

    if not listing_ids:
        return jsonify({"error": "listing_ids required"}), 400

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # Fetch prices
            cur.execute(
                "SELECT id, price_cents FROM listings WHERE id = ANY(%s) AND active = true",
                (listing_ids,),
            )
            listings = cur.fetchall()
            if len(listings) != len(listing_ids):
                return jsonify({"error": "One or more listings unavailable"}), 400

            total = sum(r[1] for r in listings)

            cur.execute(
                "INSERT INTO orders (buyer_id, total_cents, status) VALUES (%s, %s, 'pending') RETURNING id",
                (g.user_id, total),
            )
            order_id = cur.fetchone()[0]

            for listing in listings:
                cur.execute(
                    "INSERT INTO order_items (order_id, listing_id) VALUES (%s, %s)",
                    (order_id, listing[0]),
                )
            conn.commit()
    finally:
        release_conn(conn)

    return jsonify({"order_id": order_id, "total_cents": total}), 201
