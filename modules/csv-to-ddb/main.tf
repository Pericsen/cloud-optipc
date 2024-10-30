provider "aws" {
  region = var.region
}

# DynamoDB Table
resource "aws_dynamodb_table" "csv_data_table" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST" # Sin límite de capacidad predefinida

  # Definimos los atributos de la tabla
  attribute {
    name = "partType"
    type = "S"
  }

  attribute {
    name = "productId"
    type = "S"
  }

  attribute {
    name = "precio"
    type = "N"
  }

  # Definimos la clave primaria
  hash_key = "partType"
  range_key = "productId"

  local_secondary_index {
    name            = "PriceIndex"
    range_key       = "precio"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }
}

resource "aws_s3_bucket" "csv_bucket" {
  bucket = "optipc-csv-storage-nic"

  tags = {
    Name = "optipc-csv-storage-nic"
    Environment = "dev"
  }
}

# Opcional: Habilitar la versión del archivo para el control de versiones (opcional)
resource "aws_s3_bucket_versioning" "csv_bucket_versioning" {
  bucket = aws_s3_bucket.csv_bucket.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "csv_file" {
  bucket = aws_s3_bucket.csv_bucket.bucket
  key    = "componentes_final.csv"
  source = var.csv_file
}

# Lambda para cargar el CSV a DynamoDB usando LabRole
resource "aws_lambda_function" "upload_csv_lambda" {
  filename         = "${path.module}/lambda.zip"
  function_name    = "${var.table_name}_upload_csv"
  role             = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.my_table.name
      S3_BUCKET      = aws_s3_bucket.csv_bucket.bucket
      S3_KEY         = aws_s3_bucket_object.csv_object.key
    }
  }

  timeout      = var.lambda_timeout
  memory_size  = var.lambda_memory
}

data "aws_caller_identity" "current" {}
