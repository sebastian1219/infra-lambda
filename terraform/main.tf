provider "aws" {
  region = "us-east-1"
}

# S3 Bucket
resource "aws_s3_bucket" "image_bucket" {
  bucket = var.bucket_name
}

# DynamoDB Table
resource "aws_dynamodb_table" "metadata_table" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "image_id"

  attribute {
    name = "image_id"
    type = "S"
  }
}

# Lambda: get_image_metadata
resource "aws_lambda_function" "get_image_metadata" {
  function_name    = "get_image_metadata"
  role             = var.lambda_role_arn
  runtime          = "python3.9"
  handler          = "lambda_function.lambda_handler"
  filename         = "${path.module}/../lambdas/get_image_metadata/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambdas/get_image_metadata/function.zip")

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
}

# Lambda: s3_file_event
resource "aws_lambda_function" "s3_file_event" {
  function_name    = "s3_file_event"
  role             = var.lambda_role_arn
  runtime          = "python3.9"
  handler          = "lambda_function.lambda_handler"
  filename         = "${path.module}/../lambdas/s3_file_event/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambdas/s3_file_event/function.zip")

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
}

# Permiso para que S3 invoque Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_file_event.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.image_bucket.arn
}

# Notificación de eventos en S3
resource "aws_s3_bucket_notification" "bucket_events" {
  bucket = aws_s3_bucket.image_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_file_event.arn
    events              = ["s3:ObjectCreated:Put", "s3:ObjectRemoved:Delete"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".jpg"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# API Gateway
resource "aws_api_gateway_rest_api" "image_metadata_api" {
  name        = "ImageMetadataAPI"
  description = "API para consultar y eliminar metadatos de imágenes"
}

# /metadata
resource "aws_api_gateway_resource" "metadata_resource" {
  rest_api_id = aws_api_gateway_rest_api.image_metadata_api.id
  parent_id   = aws_api_gateway_rest_api.image_metadata_api.root_resource_id
  path_part   = "metadata"
}

# GET /metadata
resource "aws_api_gateway_method" "get_all_metadata" {
  rest_api_id   = aws_api_gateway_rest_api.image_metadata_api.id
  resource_id   = aws_api_gateway_resource.metadata_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_all_metadata_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_metadata_api.id
  resource_id             = aws_api_gateway_resource.metadata_resource.id
  http_method             = aws_api_gateway_method.get_all_metadata.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_image_metadata.invoke_arn
}

# /metadata/{image_id}
resource "aws_api_gateway_resource" "metadata_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.image_metadata_api.id
  parent_id   = aws_api_gateway_resource.metadata_resource.id
  path_part   = "{image_id}"
}

# GET /metadata/{image_id}
resource "aws_api_gateway_method" "get_metadata_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.image_metadata_api.id
  resource_id   = aws_api_gateway_resource.metadata_id_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_metadata_by_id_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_metadata_api.id
  resource_id             = aws_api_gateway_resource.metadata_id_resource.id
  http_method             = aws_api_gateway_method.get_metadata_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_image_metadata.invoke_arn
}

# DELETE /metadata/{image_id}
resource "aws_api_gateway_method" "delete_metadata_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.image_metadata_api.id
  resource_id   = aws_api_gateway_resource.metadata_id_resource.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "delete_metadata_by_id_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_metadata_api.id
  resource_id             = aws_api_gateway_resource.metadata_id_resource.id
  http_method             = aws_api_gateway_method.delete_metadata_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_image_metadata.invoke_arn
}

# Permiso para que API Gateway invoque Lambda
resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_image_metadata.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image_metadata_api.execution_arn}/*/*"
}

# Despliegue
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.get_all_metadata_integration,
    aws_api_gateway_integration.get_metadata_by_id_integration,
    aws_api_gateway_integration.delete_metadata_by_id_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.image_metadata_api.id
}

# Etapa
resource "aws_api_gateway_stage" "api_stage" {
  rest_api_id   = aws_api_gateway_rest_api.image_metadata_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = "prod"
}

# Output
output "api_url" {
  value = "https://${aws_api_gateway_rest_api.image_metadata_api.id}.execute-api.${var.region}.amazonaws.com/prod/metadata"
}
