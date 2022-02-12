resource "aws_s3_bucket" "private" {
  bucket = "private-sasaki-bucket"
}

resource "aws_s3_bucket_versioning" "private_bucket_versioning" {
  bucket = aws_s3_bucket.private.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private_bucket_server_side_encryption_configuration" {
  bucket = aws_s3_bucket.private.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "private" {
  bucket                  = aws_s3_bucket.private.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "public" {
  bucket = "public-sasaki-bucket"
}

resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.public.id
  acl    = "public-read"
}

resource "aws_s3_bucket_cors_configuration" "public" {
  bucket = aws_s3_bucket.public.id

  cors_rule {
    allowed_origins = ["https://example.com"]
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_versioning" "public_bucket_versioning" {
  bucket = aws_s3_bucket.public.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "alb_log" {
  bucket        = "alb-log-sasaki-cerated-by-terraform"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_log_lifecycle_configuration" {
  bucket = aws_s3_bucket.alb_log.id

  rule {
    id = "alb_log"

    status = "Enabled"

    expiration {
      days = 180
    }
  }
}

resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  policy = data.aws_iam_policy_document.alb_log.json
}

data "aws_iam_policy_document" "alb_log" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.alb_log.id}/*"]

    principals {
      type        = "AWS"
      identifiers = ["582318560864"]
    }
  }
}
