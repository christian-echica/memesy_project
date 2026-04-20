terraform {
  backend "s3" {
    bucket         = "memesy-tfstate-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "memesy-tfstate-lock"
  }
}

# Bootstrap the state bucket and DynamoDB lock table once before first apply:
#   aws s3api create-bucket --bucket memesy-tfstate-prod --region us-east-1
#   aws s3api put-bucket-versioning --bucket memesy-tfstate-prod --versioning-configuration Status=Enabled
#   aws s3api put-bucket-encryption --bucket memesy-tfstate-prod \
#     --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#   aws dynamodb create-table --table-name memesy-tfstate-lock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST --region us-east-1
