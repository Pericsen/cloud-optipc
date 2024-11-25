   ####################################
########       VPC ENDPOINT       ########
   ####################################


resource "aws_vpc_endpoint" "dynamodb_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}


   ####################################
########         DYNAMODB         ########
   ####################################

resource "aws_dynamodb_table" "csv_data_table" {
  name         = "componentes"
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
    name = "precio_ficticio"
    type = "S"
  }

  # Definimos la clave primaria
  hash_key = "partType"
  range_key = "productId"

  local_secondary_index {
    name            = "precio-index"
    range_key       = "precio_ficticio"
    projection_type = "ALL"
  }

  # local_secondary_index {
  #   name            = "RecommendationIndex"
  #   range_key       = "precio"
  #   projection_type = "ALL"
  # }

  # Opcional: Habilitar la recuperación de eventos (TTL) para eliminar entradas antiguas
  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  stream_enabled   = true # activa streams para SNS
  stream_view_type = "NEW_AND_OLD_IMAGES" # Configura las imágenes nuevas y viejas
}

resource "aws_dynamodb_table" "model_data_table" {
  name         = "optimizaciones"
  billing_mode = "PAY_PER_REQUEST" # Sin límite de capacidad predefinida

  # Definimos los atributos de la tabla
  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "datetime"
    type = "S"
  }

  hash_key = "userId"
  range_key = "datetime"

  # Opcional: Habilitar la recuperación de eventos (TTL) para eliminar entradas antiguas
  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }
}