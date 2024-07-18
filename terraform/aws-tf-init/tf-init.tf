locals {
  buckets = ["tf-state-${var.env}"]
  env     = replace(var.env, "-", "_")
  dynamodb_tables = [
    # "tf_state_${local.env}",
  ]
}

resource "aws_s3_bucket" "terraform_bucket" {
  count  = length(local.buckets)
  bucket = local.buckets[count.index]
  tags = {
    Name = "S3 Remote Terraform State Store"
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  count          = length(local.dynamodb_tables)
  name           = local.dynamodb_tables[count.index]
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    "Name" = "DynamoDB Terraform State Lock Table"
  }
}

## Outputs: ##
output "buckets_names" {
  value = aws_s3_bucket.terraform_bucket[*].id
}
output "bucket_arn" {
  value = aws_s3_bucket.terraform_bucket[*].arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_lock[*].name
}
output "dynamodb_table_arn" {
  value = aws_dynamodb_table.terraform_lock[*].arn
}
