terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.region_name
  profile = "AdministratorAccess-953264846691"
}

#define variables
locals {
  layer_zip_path    = "layer.zip"
  layer_name        = "lambda_layer"
  requirements_path = "${path.module}/../requirements.txt"
}

# Assigning IAM role to the lambda function
resource "aws_iam_role" "lambda" {
  name = "lambda"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}


# Give the lambda function permission to read and write to the S3 buckets
resource "aws_iam_policy" "lambda" {
  name        = "lambda"
  description = "Allow lambda to read and write to S3 buckets"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = [
          aws_s3_bucket.landing_bucket.arn,
          "${aws_s3_bucket.landing_bucket.arn}/*",
          aws_s3_bucket.target_bucket.arn,
          "${aws_s3_bucket.target_bucket.arn}/*"
        ],
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ],
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

# create zip file from requirements.txt. Triggers only when the file is updated
resource "null_resource" "lambda_layer" {
  triggers = {
    requirements_hash = filebase64sha256(local.requirements_path)
  }
  # the command to install python and dependencies to the machine and zips
  provisioner "local-exec" {
    command = <<EOT
        echo "creating layers with requirements.txt packages..."

        cd ..

        # Create and activate virtual environment...
        python -m venv python
        source python/bin/activate

        # Installing python dependencies...
        
        pip install -r requirements.txt
        zip -r layer.zip python

        # Deactivate virtual environment...
        deactivate

        #deleting the python dist package modules
        rm -rf python
    EOT
  }
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename         = "${path.module}/../layer.zip"
  layer_name       = "lambda_layer"
  source_code_hash = filebase64sha256("../layer.zip")
  depends_on       = [null_resource.lambda_layer]
}

# Create a lambda function to process the data
resource "aws_lambda_function" "fetch_fuel_prices" {
  filename         = "../lambda/function.zip"
  function_name    = "fetch_fuel_prices"
  role             = aws_iam_role.lambda.arn
  description      = "This function fetches the fuel prices from the gov.uk website"
  handler          = "function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("../lambda/function.zip")
  timeout          = 60
  ## lambda layer alread diclared and attached 
  depends_on = [null_resource.lambda_layer]

  layers = [aws_lambda_layer_version.lambda_layer.arn]

}

resource "aws_lambda_function" "fetch_costco_fuel_prices" {
  filename         = data.archive_file.zip_the_costco_python_code.output_path
  function_name    = "fetch_costco_fuel_prices"
  role             = aws_iam_role.lambda.arn
  description      = "This function fetches the fuel prices from the costco website"
  handler          = "costco.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256(data.archive_file.zip_the_costco_python_code.output_path)
  timeout          = 300
  depends_on       = [data.archive_file.zip_the_costco_python_code, null_resource.lambda_layer]
  layers           = [aws_lambda_layer_version.lambda_layer.arn]

}

# CloudWatch Event to trigger Lambda daily at 12 noon.
resource "aws_cloudwatch_event_rule" "daily_12pm" {
  name                = "daily_12pm"
  schedule_expression = "cron(0 12 * * ? *)"
}

resource "aws_cloudwatch_event_rule" "daily_9am" {
  name                = "daily_9am"
  schedule_expression = "cron(0 9 * * ? *)"
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_12pm.name
  target_id = aws_lambda_function.fetch_fuel_prices.function_name
  arn       = aws_lambda_function.fetch_fuel_prices.arn
}

resource "aws_cloudwatch_event_target" "lambda_target_costco" {
  rule      = aws_cloudwatch_event_rule.daily_9am.name
  target_id = aws_lambda_function.fetch_costco_fuel_prices.function_name
  arn       = aws_lambda_function.fetch_costco_fuel_prices.arn
}

# Permission for CloudWatch to invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch_1" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_fuel_prices.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_12pm.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_2" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_costco_fuel_prices.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_9am.arn
}

# Create a Glue Catalog Database
resource "aws_glue_catalog_database" "glue_catalog_database" {
  name = "fuel_prices_database_wk"
}

resource "aws_athena_workgroup" "fuel_prices_workgroup" {
  name = "fuel_prices_workgroup"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_outputs_bucket.bucket}/"
    }
  }
}
