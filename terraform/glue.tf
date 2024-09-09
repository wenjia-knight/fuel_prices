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
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:UpdateCrawler",
          "glue:DeleteCrawler",
          "glue:CreateCrawler",
          "glue:StopCrawler"
        ]
        Resource = [
          aws_glue_crawler.crawler.arn
        ]
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "glue_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_policy.arn
}

# Create a Glue job
resource "aws_glue_job" "my_glue_job" {
  name     = "from-raw-to-processed"
  role_arn = aws_iam_role.glue_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://${var.glue_script_bucket_name}/glue-job-script.py"
    python_version  = "3"
  }

  max_retries       = 1
  glue_version      = "4.0"
  number_of_workers = 10
  worker_type       = "G.1X"
  timeout           = 2880
}

# start glue job on schedule daily
resource "aws_glue_trigger" "start_glue_job_trigger" {
  name     = "start-glue-job-trigger"
  type     = "SCHEDULED"
  schedule = "cron(15 12 * * ? *)" # Daily at 12:15 UTC
  actions {
    job_name = aws_glue_job.my_glue_job.name
  }
  workflow_name = aws_glue_workflow.my_glue_workflow.name
  depends_on    = [aws_glue_job.my_glue_job]
}

# Trigger the glue crawler after the glue job is completed
resource "aws_glue_trigger" "trigger_crawler" {
  name = "trigger-crawler"
  type = "CONDITIONAL"
  predicate {
    conditions {
      job_name = aws_glue_job.my_glue_job.name
      state    = "SUCCEEDED"
    }
  }
  actions {
    crawler_name = aws_glue_crawler.crawler.name
  }
  workflow_name = aws_glue_workflow.my_glue_workflow.name
}

resource "aws_glue_crawler" "crawler" {
  name          = "fuel-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.glue_catalog_database.name
  s3_target {
    path = "s3://${aws_s3_bucket.target_bucket.bucket}"
  }
  configuration = jsonencode({
    Version = 1.0,
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    },
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })
}

resource "aws_glue_workflow" "my_glue_workflow" {
  name = "fuel-price-glue-workflow"
}
