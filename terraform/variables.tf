variable "region_name" {
  description = "The AWS region to launch the resources."
  type        = string
  default     = "eu-west-2"
}

variable "lambda_runtime" {
  description = "The runtime for the lambda function."
  type        = string
  default     = "python3.12"
}