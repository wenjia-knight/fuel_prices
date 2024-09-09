# Create a S3 bucket for the raw JSON files to land
resource "aws_s3_bucket" "landing_bucket" {
  bucket        = var.landing_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "block_settings_landing_bucket" {
  bucket = aws_s3_bucket.landing_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket" "target_bucket" {
  bucket        = var.target_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "block_settings_target_bucket" {
  bucket = aws_s3_bucket.target_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Create a S3 bucket for athena outputs
resource "aws_s3_bucket" "athena_outputs_bucket" {
  bucket        = var.athena_outputs_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "block_settings_athena_output_bucket" {
  bucket = aws_s3_bucket.athena_outputs_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Create a S3 bucket for storing glue script
resource "aws_s3_bucket" "glue_script_bucket" {
  bucket        = var.glue_script_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "block_settings_glue_script_bucket" {
  bucket = aws_s3_bucket.glue_script_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
# Upload the glue job script to the S3 bucket
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.glue_script_bucket.bucket
  key    = "glue-job-script.py"
  source = "../glue_script/glue_job_script.py"
  etag   = filemd5("../glue_script/glue_job_script.py")
}