#!/usr/bin/env python3
"""
Seed script: creates schema + 8 test users (shared password) + 5-6 meme listings each.
Run as a one-off ECS task with command override: ["python", "db/seed.py"]
All DB credentials come from the same env vars used by the services.
"""

import os
import sys

import bcrypt
import psycopg2

DB_CONFIG = {
    "host":     os.environ["DB_HOST"],
    "port":     int(os.environ.get("DB_PORT", 5432)),
    "dbname":   os.environ["DB_NAME"],
    "user":     os.environ["DB_USER"],
    "password": os.environ["DB_PASSWORD"],
    "sslmode":  "require",
}

SHARED_PASSWORD = "Memesy123!"

USERS = [
    {"email": "alice@test.com",  "name": "Alice"},
    {"email": "bob@test.com",    "name": "Bob"},
    {"email": "carol@test.com",  "name": "Carol"},
    {"email": "dave@test.com",   "name": "Dave"},
    {"email": "eve@test.com",    "name": "Eve"},
    {"email": "frank@test.com",  "name": "Frank"},
    {"email": "grace@test.com",  "name": "Grace"},
    {"email": "henry@test.com",  "name": "Henry"},
]

MEME_TITLES = [
    "When the code works on first try",
    "Monday morning vibes",
    "Me explaining my code to rubber duck",
    "Senior dev vs junior dev",
    "When the client wants one small change",
    "Stack Overflow to the rescue",
    "Debugging at 3am",
    "When you delete node_modules",
    "Agile standup bingo",
    "Git blame yourself",
    "404 brain not found",
    "Works on my machine",
    "Pushed to main directly",
    "The infinite loading spinner",
    "CSS is my passion",
    "SQL joins be like",
    "When prod goes down on Friday",
    "The merge conflict nightmare",
    "Scope creep meme",
    "My code has no bugs",
    "Tab vs spaces war",
    "Localhost is not a real server",
    "Ship it before testing",
    "The tech debt monster",
    "10x developer starter pack",
    "When your regex works",
    "Legacy code horror",
    "The standup that could've been an email",
    "Deploy Friday meme",
    "null pointer exception again",
    "Microservices vs monolith",
    "Infinite scroll trap",
    "Dark mode enjoyer",
    "sudo make me a sandwich",
    "It's not a bug, it's a feature",
    "When the intern breaks prod",
    "LGTM without reading",
    "The ticket with no description",
    "Everyone loves code review",
    "Requirements that change every week",
    "Caffeine-driven development",
    "When you finally fix the bug",
    "Variable named temp2Final",
    "Comment says one thing, code does another",
    "The 1000-line function",
    "We'll refactor it later",
    "Unit tests? Never heard of her",
    "Please update the docs",
]

PRICES = [199, 299, 399, 499, 599, 699, 799, 999]


def placeholder_url(seed: int) -> str:
    return f"https://picsum.photos/seed/{seed}/400/400"


def run():
    print("Connecting to database…")
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = False

    with conn.cursor() as cur:
        # ── Schema ────────────────────────────────────────────────────────────
        schema_path = os.path.join(os.path.dirname(__file__), "schema.sql")
        with open(schema_path) as f:
            cur.execute(f.read())
        print("Schema applied.")

        # ── Password hash ─────────────────────────────────────────────────────
        pw_hash = bcrypt.hashpw(SHARED_PASSWORD.encode(), bcrypt.gensalt()).decode()

        # ── Users ─────────────────────────────────────────────────────────────
        user_ids = []
        for u in USERS:
            cur.execute(
                """
                INSERT INTO users (email, password_hash)
                VALUES (%s, %s)
                ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash
                RETURNING id
                """,
                (u["email"], pw_hash),
            )
            user_ids.append(cur.fetchone()[0])
        print(f"Upserted {len(user_ids)} users.")

        # ── Listings ──────────────────────────────────────────────────────────
        import random
        random.seed(42)
        titles = MEME_TITLES[:]
        random.shuffle(titles)

        listing_count = 0
        img_seed = 10
        for i, user_id in enumerate(user_ids):
            count = 5 if i % 2 == 0 else 6
            for j in range(count):
                title = titles.pop() if titles else f"Meme #{listing_count + 1}"
                price = PRICES[(listing_count) % len(PRICES)]
                preview = placeholder_url(img_seed)
                img_seed += 1
                cur.execute(
                    """
                    INSERT INTO listings (title, price_cents, preview_url, seller_id, active)
                    VALUES (%s, %s, %s, %s, true)
                    """,
                    (title, price, preview, user_id),
                )
                listing_count += 1
        print(f"Inserted {listing_count} listings.")

    conn.commit()
    conn.close()
    print("Seed complete.")


if __name__ == "__main__":
    try:
        run()
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
