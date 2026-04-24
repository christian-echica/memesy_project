-- Run once to bootstrap the database schema.
-- Safe to re-run: all statements use IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS users (
    id            SERIAL PRIMARY KEY,
    email         VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS listings (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    price_cents INTEGER NOT NULL CHECK (price_cents > 0),
    asset_key   VARCHAR(512),
    preview_url VARCHAR(512),
    attributes  JSONB DEFAULT '{}',
    seller_id   INTEGER REFERENCES users(id) ON DELETE SET NULL,
    active      BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_listings_active_created ON listings (active, created_at DESC);

CREATE TABLE IF NOT EXISTS orders (
    id          SERIAL PRIMARY KEY,
    buyer_id    INTEGER REFERENCES users(id) ON DELETE SET NULL,
    listing_id  INTEGER REFERENCES listings(id) ON DELETE SET NULL,
    amount_cents INTEGER NOT NULL,
    status      VARCHAR(50) DEFAULT 'pending',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
