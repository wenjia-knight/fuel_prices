# Create an IAM role for Glue
resource "aws_iam_role" "glue_role" {
  name = "GlueETLRole"

  assume_role_policy = data.aws_iam_policy_document.glue_assume_role.json
}

# Create an IAM policy for Glue
resource "aws_iam_policy" "glue_policy" {
  name        = "GlueETLPolicy"
  description = "IAM policy for Glue ETL job"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.landing_bucket.arn,
          "${aws_s3_bucket.landing_bucket.arn}/*",
          aws_s3_bucket.target_bucket.arn,
          "${aws_s3_bucket.target_bucket.arn}/*",
          "arn:aws:s3:::aws-glue-assets-240998004757-eu-west-2/*",
          "${aws_s3_bucket.glue_script_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:*",
          "iam:ListRole",
          "iam:GetRole",
          "iam:passRole",
          "iam:GetRolePolicy"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:/aws-glue/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "codewhisperer:GenerateRecommendations",
          "codewhisperer:CreateCodeScan",
          "codewhisperer:GetCodeScan",
          "codewhisperer:ListCodeScanFindings",
          "codewhisperer:ListRecommendations",
          "cloudwatch:PutMetricData",
          "codecatalyst:GetProject",
          "codecatalyst:ListProjects",
          "codecatalyst:GetSpace",
          "codecatalyst:ListSpaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "glue_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_policy.arn
}

resource "aws_glue_job" "your_glue_job" {
  name        = "from-raw-to-processed"
  role_arn    = aws_iam_role.glue_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://${var.glue_script_bucket_name}/glue-job-script.py"
    python_version  = "3"
  }

  # default_arguments = {
  #   "--job-bookmark-option" = "job-bookmark-enable"
  #   # "--TempDir"             = "s3://your-temp-dir/"
  # }

  max_retries          = 1
  glue_version         = "4.0"
  number_of_workers    = 10
  worker_type          = "G.1X"
  timeout              = 2880
}

resource "aws_glue_trigger" "daily_trigger" {
  name     = "daily-trigger"
  type     = "SCHEDULED"
  schedule = "cron(15 12 * * ? *)"  # Daily at 12:15 UTC
  actions {
    job_name = aws_glue_job.your_glue_job.name
  }
  # start_on_creation = true
}