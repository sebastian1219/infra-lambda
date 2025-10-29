variable "bucket_name" {
  type = string
}

variable "table_name" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}
