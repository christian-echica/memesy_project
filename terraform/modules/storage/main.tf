locals {
  name = "${var.project}-${var.env}"
  tags = merge(var.tags, { Module = "storage" })
}

# ── Media Bucket (raw assets — never public) ──────────────────────────────────

resource "aws_s3_bucket" "media" {
  bucket = "${local.name}-media-${var.account_id}"
  tags   = merge(local.tags, { Name = "${local.name}-media" })
}

# Versioning intentionally disabled — one authoritative copy per asset,
# buyers get scoped signed URLs rather than object versions.
resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration { status = "Suspended" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    id     = "ia-transition"
    status = "Enabled"
    filter { prefix = "" }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }

  # Abort incomplete multipart uploads to avoid orphaned part charges
  rule {
    id     = "abort-incomplete-mpu"
    status = "Enabled"
    filter { prefix = "" }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Frontend Bucket (React SPA static files) ──────────────────────────────────

resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name}-frontend-${var.account_id}"
  tags   = merge(local.tags, { Name = "${local.name}-frontend" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "abort-incomplete-mpu"
    status = "Enabled"
    filter { prefix = "" }
    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
