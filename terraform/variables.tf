variable "region_name" {
  description = "The AWS region to launch the resources."
  type        = string
  default     = "eu-west-1"
}

variable "lambda_runtime" {
  description = "The runtime for the lambda function."
  type        = string
  default     = "python3.12"
}

variable "landing_bucket_name" {
  description = "The name of the landing bucket for storing raw files."
  type        = string
  default     = "fuel-prices-raw-bucket-wk"
}

variable "target_bucket_name" {
  description = "The name of the target bucket for storing processed files."
  type        = string
  default     = "fuel-prices-processed-bucket-wk"

}
variable "athena_outputs_bucket_name" {
  description = "The name of the bucket for storing Athena outputs."
  type        = string
  default     = "fuel-prices-athenaoutputs-bucket-wk"
}

variable "glue_script_bucket_name" {
  description = "The name of the bucket for storing glue script."
  type        = string
  default     = "fuel-prices-glue-script-bucket-wk"
}