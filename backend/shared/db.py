import os
from psycopg2 import pool

_pool: pool.ThreadedConnectionPool | None = None


def get_pool() -> pool.ThreadedConnectionPool:
    global _pool
    if _pool is None:
        _pool = pool.ThreadedConnectionPool(
            minconn=2,
            maxconn=10,
            host=os.environ["DB_HOST"],
            port=int(os.environ.get("DB_PORT", 5432)),
            dbname=os.environ["DB_NAME"],
            user=os.environ["DB_USER"],
            password=os.environ["DB_PASSWORD"],
            sslmode="require",
        )
    return _pool


def get_conn():
    return get_pool().getconn()


def release_conn(conn) -> None:
    get_pool().putconn(conn)
