provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "image_bucket" {
  bucket = var.bucket_name
}

resource "aws_dynamodb_table" "metadata_table" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "image_id"

  attribute {
    name = "image_id"
    type = "S"
  }
}

resource "aws_lambda_function" "get_image_metadata" {
  function_name = "get_image_metadata"
  role          = var.lambda_role_arn
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  filename      = "${path.module}/../lambdas/get_image_metadata/function.zip"

  source_code_hash = filebase64sha256("${path.module}/../lambdas/get_image_metadata/function.zip")

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
}

resource "aws_lambda_function" "s3_file_event" {
  function_name = "s3_file_event"
  role          = var.lambda_role_arn
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  filename      = "${path.module}/../lambdas/s3_file_event/function.zip"

  source_code_hash = filebase64sha256("${path.module}/../lambdas/s3_file_event/function.zip")

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
}

resource "aws_s3_bucket_notification" "bucket_events" {
  bucket = aws_s3_bucket.image_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_file_event.arn
    events              = ["s3:ObjectCreated:Put", "s3:ObjectRemoved:Delete"]
    filter_prefix       = "uploads/"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_file_event.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.image_bucket.arn
}
