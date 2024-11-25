   ####################################
########        FRONTEND S3       ########
   ####################################
   
resource "aws_s3_bucket" "frontend_bucket"{
    bucket = var.bucket_name

    tags={
        Name = var.bucket_name
        Author = "G32024Q2"
    }
}

# Configuración del alojamiento de sitios web estáticos
resource "aws_s3_bucket_website_configuration" "frontend_bucket_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Configuración del versionado (en este caso, deshabilitado)
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.frontend_bucket.bucket

  versioning_configuration {
    status = "Suspended" # Suspende el versionado, equivalente a "desactivado"
  }
}

# Desbloquear políticas públicas en el bucket
resource "aws_s3_bucket_public_access_block" "frontend_bucket_block" {
  bucket = aws_s3_bucket.frontend_bucket.bucket

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Política del bucket para permitir acceso público a los archivos
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.frontend_bucket_block
  ]

}

resource "aws_s3_bucket_cors_configuration" "frontend_cors" {
  bucket = aws_s3_bucket.frontend_bucket.id

  cors_rule {
    allowed_methods = ["GET","POST"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
  }
}

# Subimos los archivos HTML, CSS y JS desde una carpeta local
resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.frontend_bucket.bucket
  key    = "index.html"
  source = "./front/index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "login_html" {
  bucket = aws_s3_bucket.frontend_bucket.bucket
  key    = "login.html"
  source = "./front/login.html"
  content_type = "text/html"
}

resource "aws_s3_object" "admin_login_html" {
  bucket = aws_s3_bucket.frontend_bucket.bucket
  key    = "admin_login.html"
  source = "./front/admin_login.html"
  content_type = "text/html"
}

resource "aws_s3_object" "css_file" {
  bucket = aws_s3_bucket.frontend_bucket.bucket
  key    = "styles.css"
  source = "./front/styles.css"
  content_type = "text/css"
}

resource "aws_s3_object" "js_file" {
  bucket = aws_s3_bucket.frontend_bucket.bucket
  key    = "functions.js"
  source = "./front/functions.js"
  content_type = "application/javascript"
}


   ####################################
########          DATA S3         ########
   ####################################

# resource "aws_s3_bucket" "csv_bucket" {
#   bucket = var.csv_bucket_name

#   tags = {
#     Name        = var.csv_bucket_name
#     Environment = "production"
#   }
# }

# resource "aws_s3_bucket_policy" "csv_bucket_policy" {
#   bucket = aws_s3_bucket.csv_bucket.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Deny"
#         Principal = "*"
#         Action   = "s3:*"
#         Resource = [
#           "${aws_s3_bucket.csv_bucket.arn}",
#           "${aws_s3_bucket.csv_bucket.arn}/*"
#         ],
#         Condition = {
#           Bool = {
#             "aws:SecureTransport": false
#           }
#         }
#       }
#     ]
#   })
# }

# resource "aws_s3_bucket_public_access_block" "csv_bucket_block" {
#   bucket                  = aws_s3_bucket.csv_bucket.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# resource "aws_s3_object" "csv_upload" {
#   bucket = aws_s3_bucket.csv_bucket.bucket
#   key    = "import/componentes_optimizados.csv"
#   source = "./data/componentes_optimizados.csv"
#   acl    = "private"
# }

# resource "aws_s3_bucket_notification" "s3_notification" {
#   bucket = aws_s3_bucket.csv_bucket.id

#   lambda_function {
#     lambda_function_arn = aws_lambda_function.csv_to_dynamodb.arn
#     events              = ["s3:ObjectCreated:*"]
#   }

#   depends_on = [
#     aws_s3_bucket.csv_bucket,
#     aws_lambda_function.csv_to_dynamodb,
#     aws_lambda_permission.allow_s3_invoke
#   ]
# }


   ###############################
########    ARCHIVO LOCAL    ########
   ###############################

// Archivo local para pasar variables de Terraform al JS del front
resource "local_file" "config_file" {
  filename = "./front/config.json"

  content = jsonencode({
    domain                = var.domain,
    user_pool_client_id   = aws_cognito_user_pool_client.user_pool_client.id
    api_gateway_id        = aws_api_gateway_rest_api.api_gateway.id
    user_pool_id          = aws_cognito_user_pool.user_pool.id
    website_endpoint      = aws_s3_bucket_website_configuration.frontend_bucket_website.website_endpoint
  })
}

resource "aws_s3_object" "config_file" {
  bucket = aws_s3_bucket.frontend_bucket.bucket
  key    = "config.json"
  source = "./front/config.json"
  content_type = "application/json"
  depends_on = [local_file.config_file]
}


# Recurso Nulo que ejecuta el comando en la terminal local que corre el csv_to_dynamo.py (script que sube el csv inicial a dynamo)
resource "null_resource" "import_csv" {
  provisioner "local-exec" {
    command = "python ./data/csv_to_dynamo.py"
  }
  
  depends_on = [aws_dynamodb_table.csv_data_table]
}