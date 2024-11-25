   ####################################
######    LAMBDAS SECURITY GROUP    ######
   ####################################

module "lambda_sg" {
  source             = "./modulos/security_group"
  vpc_id             = module.vpc.vpc_id
  ingress_from_port  = 0
  ingress_to_port    = 0
  ingress_protocol   = "-1"
  ingress_cidr_blocks = ["10.0.0.0/16"]
  egress_from_port   = 0
  egress_to_port     = 0
  egress_protocol    = "-1"
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


   ####################################
########          LAMBDAS         ########
   ####################################

/// LAMBDA PARA CONVERTIR URL HTTP A HTTPS Y REDIRIGIR A COGNITO UI
resource "aws_lambda_function" "https_lambda" {
  function_name = "https_lambda"
  runtime       = "nodejs18.x"
  handler       = "https_lambda.handler"
  role          = data.aws_iam_role.labrole.arn

  filename      = "./lambdas/https_lambda.zip"
  source_code_hash = filebase64sha256("./lambdas/https_lambda.zip")

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.user_pool.id,
      REDIRECT_ADMIN_URL        = "http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com/admin_login.html",
      REDIRECT_USER_URL        = "http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com/login.html",
      LOGOUT_REDIRECT_URL = "http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com/index.html",
      CLIENT_ID = aws_cognito_user_pool_client.user_pool_client.id
    }
  }
}

/// LAMBDA PARA SUBIR DATA DE CSV A DYNAMO DESDE EL FRONT
resource "aws_lambda_function" "upload_data_lambda" {
  function_name    = "upload_data_lambda"
  runtime          = "python3.9"
  handler          = "upload_lambda.lambda_handler"
  role             = data.aws_iam_role.labrole.arn

  filename         = "./lambdas/upload_lambda.zip"

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.csv_data_table.name,
      BUCKET_NAME = var.bucket_name
    }
  }

  timeout = 300
}


/// LAMBDA PARA EJECUTAR MODELO OPTIMIZACIÓN
resource "aws_lambda_function" "optimization_lambda" {
  function_name = "optimization_lambda-${each.key}"
  runtime       = "python3.9"
  handler       = "optimization_lambda.lambda_handler"
  role          = data.aws_iam_role.labrole.arn

  filename      = "./lambdas/optimization_lambda.zip"

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
    }
  }

  for_each = {
    "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
    "us-east-1b" = element(module.vpc.private_subnets, 1)
  }

  vpc_config {
    subnet_ids         = [each.value]
    security_group_ids = [module.lambda_sg.lambda_security_group_id]
  }

  layers = [
    data.klayers_package_latest_version.pandas.arn
  ]

  timeout = 300
}

// LAMBDA PARA EJECUTAR MODIFICAR COMPONENTES
resource "aws_lambda_function" "modify_lambda" {
  function_name = "modify_lambda-${each.key}"
  runtime       = "python3.9"
  handler       = "modify_lambda.lambda_handler"
  role          = data.aws_iam_role.labrole.arn
  filename      = "./lambdas/modify_lambda.zip"
  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
    }
  }

  for_each = {
    "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
    "us-east-1b" = element(module.vpc.private_subnets, 1)
  }

  vpc_config {
    subnet_ids         = [each.value]
    security_group_ids = [module.lambda_sg.lambda_security_group_id]
  }

  layers = [
    data.klayers_package_latest_version.pandas.arn
  ]

  timeout = 300
}


/// LAMBDA PARA ENVIAR NOTIFICACIONES MEDIANTE SNS (AL SUBIR DATA A DYNAMO)
resource "aws_lambda_function" "SNS_lambda" {
  function_name = "SNS_lambda"
  runtime       = "python3.9"
  handler       = "SNS_lambda.lambda_handler"
  role          = data.aws_iam_role.labrole.arn

  filename      = "./lambdas/SNS_lambda.zip"
  source_code_hash = filebase64sha256("./lambdas/SNS_lambda.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = module.sns.sns_topic_arn
    }
  }
}

resource "aws_lambda_permission" "allow_dynamodb_invoke" {
  statement_id  = "AllowExecutionFromDynamoDB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.SNS_lambda.function_name
  principal     = "dynamodb.amazonaws.com"
  source_arn    = aws_dynamodb_table.csv_data_table.stream_arn
}

resource "aws_lambda_event_source_mapping" "dynamodb_to_lambda" {
  event_source_arn  = aws_dynamodb_table.csv_data_table.stream_arn
  function_name     = aws_lambda_function.SNS_lambda.arn
  starting_position = "LATEST"
  batch_size        = 100
}