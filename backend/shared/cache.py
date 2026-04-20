import os
import redis

# TLS connection to ElastiCache Redis (transit_encryption_enabled = true)
redis_client = redis.Redis(
    host=os.environ["REDIS_HOST"],
    port=int(os.environ.get("REDIS_PORT", 6379)),
    password=os.environ.get("REDIS_AUTH_TOKEN"),
    ssl=True,
    decode_responses=True,
)
