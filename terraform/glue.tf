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
          "arn:aws:s3:::aws-glue-assets-240998004757-eu-west-2/*"
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
