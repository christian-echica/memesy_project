terraform {
  backend "s3" {
    bucket         = "memesy-tfstate-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}

# Bootstrap the state bucket once before first init (use_lockfile stores lock in S3 — no DynamoDB needed):
#   aws s3api create-bucket --bucket memesy-tfstate-prod --region us-east-1
#   aws s3api put-bucket-versioning --bucket memesy-tfstate-prod --versioning-configuration Status=Enabled
#   aws s3api put-public-access-block --bucket memesy-tfstate-prod \
#     --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
#   aws s3api put-bucket-encryption --bucket memesy-tfstate-prod \
#     --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
