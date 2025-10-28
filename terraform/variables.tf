variable "bucket_name" {
  description = "Nombre del bucket S3 para almacenar imágenes"
  type        = string
}

variable "table_name" {
  description = "Nombre de la tabla DynamoDB para metadatos"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN del rol de ejecución para funciones Lambda"
  type        = string
}

