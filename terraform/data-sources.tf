data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "glue_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}


data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_file = "${path.module}/../lambda/function.py"
  output_path = "${path.module}/../lambda/function.zip"
}

data "archive_file" "zip_the_costco_python_code" {
  type        = "zip"
  source_file = "${path.module}/../lambda/costco.py"
  output_path = "${path.module}/../lambda/costco.zip"
}