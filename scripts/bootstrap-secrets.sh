#!/usr/bin/env bash
# Creates all SSM parameters needed by Memesy from scratch.
# Run once before `terraform apply` on a fresh account.
#
# Usage:
#   export AWS_REGION=us-east-1
#   export STRIPE_SECRET_KEY=sk_test_...
#   export STRIPE_WEBHOOK_SECRET=whsec_...
#   bash scripts/bootstrap-secrets.sh
#
# DB_PASSWORD and REDIS_AUTH_TOKEN are auto-generated if not set.

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT:-memesy}"
ENV="${ENV:-prod}"
PREFIX="/${PROJECT}/${ENV}"

# ── Helpers ───────────────────────────────────────────────────────────────────

put_param() {
  local name="$1"
  local value="$2"
  local type="${3:-SecureString}"
  echo "  → ${PREFIX}/${name}"
  aws ssm put-parameter \
    --name "${PREFIX}/${name}" \
    --value "$value" \
    --type "$type" \
    --overwrite \
    --region "$REGION" \
    --output none
}

random_password() {
  # 32 chars, alphanumeric + special (SSM-safe)
  tr -dc 'A-Za-z0-9!@#$%^&*()_+' </dev/urandom | head -c 32
}

# ── Validate required inputs ──────────────────────────────────────────────────

if [[ -z "${STRIPE_SECRET_KEY:-}" ]]; then
  echo "ERROR: STRIPE_SECRET_KEY is not set."
  echo "  Get it from: https://dashboard.stripe.com/test/apikeys"
  exit 1
fi

if [[ -z "${STRIPE_WEBHOOK_SECRET:-}" ]]; then
  echo "ERROR: STRIPE_WEBHOOK_SECRET is not set."
  echo "  Get it from: https://dashboard.stripe.com/test/workbench/webhooks"
  echo "  Create endpoint: https://app.christianechica.com/api/webhook/stripe"
  echo "  Event: payment_intent.succeeded"
  exit 1
fi

# ── Generate passwords if not provided ───────────────────────────────────────

DB_PASSWORD="${DB_PASSWORD:-$(random_password)}"
REDIS_AUTH_TOKEN="${REDIS_AUTH_TOKEN:-$(random_password)}"

echo "Bootstrapping SSM parameters under ${PREFIX}/ in ${REGION}..."
echo ""

put_param "db/password"            "$DB_PASSWORD"
put_param "redis/auth-token"       "$REDIS_AUTH_TOKEN"
put_param "stripe-secret-key"      "$STRIPE_SECRET_KEY"
put_param "stripe-webhook-secret"  "$STRIPE_WEBHOOK_SECRET"

echo ""
echo "Done. All parameters created."
echo ""
echo "IMPORTANT — save these generated values if you need them later:"
echo "  DB_PASSWORD:       ${DB_PASSWORD}"
echo "  REDIS_AUTH_TOKEN:  ${REDIS_AUTH_TOKEN}"
echo ""
echo "Next step: terraform apply"
