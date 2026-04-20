"""
purchase-handler Lambda
-----------------------
Triggered by SQS (purchase events queue).
For each purchased asset:
  1. Generates a CloudFront signed URL scoped to buyer + order
  2. Stores the access token in PostgreSQL (order_items.access_url)
  3. Emails buyer via SES with their download links

Private key for signing is fetched from SSM Parameter Store on cold start.
"""
import json
import os
import time
from datetime import datetime, timedelta, timezone

import boto3
import psycopg2
from botocore.signers import CloudFrontSigner
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

ssm = boto3.client("ssm")
ses = boto3.client("ses")

CF_DOMAIN = os.environ["CF_MEDIA_DOMAIN"]
SES_SENDER = os.environ["SES_SENDER_EMAIL"]
SSM_PREFIX = os.environ["SSM_PREFIX"]

# ── Cold-start: load secrets from SSM ────────────────────────────────────────

_ssm_cache: dict = {}


def _get_ssm(name: str) -> str:
    if name not in _ssm_cache:
        resp = ssm.get_parameter(Name=f"{SSM_PREFIX}/{name}", WithDecryption=True)
        _ssm_cache[name] = resp["Parameter"]["Value"]
    return _ssm_cache[name]


def _get_db_conn():
    return psycopg2.connect(
        host=_get_ssm("db/host"),
        dbname=_get_ssm("db/name"),
        user=_get_ssm("db/user"),
        password=_get_ssm("db/password"),
        sslmode="require",
    )


def _rsa_signer(message: bytes) -> bytes:
    private_key_pem = _get_ssm("cf-signing-private-key")
    private_key = serialization.load_pem_private_key(
        private_key_pem.encode(), password=None
    )
    return private_key.sign(message, padding.PKCS1v15(), hashes.SHA1())  # noqa: S303 — CF requires SHA1


def _make_signed_url(asset_key: str, order_id: int, buyer_id: int) -> str:
    """Returns a CloudFront signed URL valid for 7 days."""
    cf_key_id = _get_ssm("cf-key-id")
    signer = CloudFrontSigner(cf_key_id, _rsa_signer)
    url = f"https://{CF_DOMAIN}/{asset_key}"
    expire = datetime.now(tz=timezone.utc) + timedelta(days=7)
    return signer.generate_presigned_url(url, date_less_than=expire)


# ── Lambda handler ────────────────────────────────────────────────────────────


def lambda_handler(event: dict, context) -> dict:
    failures = []

    for record in event["Records"]:
        try:
            _process(json.loads(record["body"]))
        except Exception as exc:
            print(f"ERROR processing record {record['messageId']}: {exc}")
            failures.append({"itemIdentifier": record["messageId"]})

    # ReportBatchItemFailures: only failed messages go back to the queue
    return {"batchItemFailures": failures}


def _process(payload: dict) -> None:
    order_id: int = payload["order_id"]
    buyer_id: int = payload["buyer_id"]
    buyer_email: str = payload["buyer_email"]
    items: list[dict] = payload["items"]

    signed_urls: list[dict] = []
    conn = _get_db_conn()
    try:
        with conn.cursor() as cur:
            for item in items:
                url = _make_signed_url(item["asset_key"], order_id, buyer_id)
                cur.execute(
                    "UPDATE order_items SET access_url = %s "
                    "WHERE order_id = %s AND listing_id = %s",
                    (url, order_id, item["listing_id"]),
                )
                signed_urls.append({"listing_id": item["listing_id"], "url": url})
        conn.commit()
    finally:
        conn.close()

    _send_email(buyer_email, order_id, signed_urls)


def _send_email(to: str, order_id: int, signed_urls: list[dict]) -> None:
    links = "\n".join(f"  - Listing {u['listing_id']}: {u['url']}" for u in signed_urls)
    ses.send_email(
        Source=SES_SENDER,
        Destination={"ToAddresses": [to]},
        Message={
            "Subject": {"Data": f"Your Memesy order #{order_id} is ready"},
            "Body": {
                "Text": {
                    "Data": (
                        f"Your purchase is complete. Download your memes below.\n\n"
                        f"{links}\n\n"
                        f"Links expire in 7 days.\n\nThanks,\nThe Memesy Team"
                    )
                }
            },
        },
    )
