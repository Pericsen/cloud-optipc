   ###########################
########       VPC       ########
   ###########################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "optipc-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
  public_subnets  = ["10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}


   ####################################
########      SECURITY GROUP      ########
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
      CLIENT_ID = aws_cognito_user_pool_client.user_pool_client.id    }
  }
}

/// LAMBDA PARA SUBIR DATA DE CSV A DYNAMO
resource "aws_lambda_function" "upload_data_lambda" {
  function_name    = "upload_data_lambda"
  runtime          = "python3.9"
  handler          = "upload_data_lambda.lambda_handler"
  role             = data.aws_iam_role.labrole.arn

  filename         = "./lambdas/upload_data_lambda.zip"

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.csv_data_table.name
    }
  }
}

# resource "aws_s3_bucket_notification" "s3_trigger_lambda" {
#   bucket = aws_s3_bucket.csv_bucket.id

#   lambda_function {
#     lambda_function_arn = aws_lambda_function.upload_data_lambda.arn
#     events              = ["s3:ObjectCreated:*"]
#     filter_suffix       = ".csv"
#   }

#   depends_on = [
#     aws_lambda_permission.allow_s3_invoke
#   ]
# }

# resource "aws_lambda_permission" "allow_s3_invoke" {
#   statement_id  = "AllowS3Invoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.upload_data_lambda.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.csv_bucket.arn
# }

/// LAMBDA PARA ENVIAR DATOS A LA EC2 (EJECUCIÓN MODELO)
resource "aws_lambda_function" "optimization_lambda" {
  function_name = "send-to-ec2-${each.key}"
  runtime       = "python3.9"
  handler       = "optimization_lambda.lambda_handler"
  role          = data.aws_iam_role.labrole.arn

  filename      = "./lambdas/optimization_lambda.zip"

  for_each = {
    "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
    "us-east-1b" = element(module.vpc.private_subnets, 1)
  }

  vpc_config {
    subnet_ids         = [each.value]
    security_group_ids = [module.lambda_sg.lambda_security_group_id]
  }

  environment {
    variables = {
      EC2_ENDPOINT = "http://${aws_instance.backend_ec2[each.key].private_ip}/optimize"
    }
  }

  depends_on = [aws_instance.backend_ec2]
}


   ####################################
########        API GATEWAY       ########
   ####################################

resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "api-gateway"
  description = "API Gateway for Lambdas redirection"
}

# resource "aws_apigatewayv2_api" "http_api" {
#   name          = "http-api-gateway"
#   description   = "HTTP API Gateway for Lambdas redirection"
#   protocol_type = "HTTP"

#   cors_configuration {
#     allow_credentials = false
#     allow_methods     = ["GET", "POST", "OPTIONS", "PUT", "DELETE"]
#     allow_origins     = ["*"]
#     allow_headers     = ["Content-Type", "Authorization"]
#     expose_headers    = ["Content-Type", "Authorization"]
#     max_age           = 3600
#   }
# }

# output "http_api_id" {
#   value = aws_apigatewayv2_api.http_api.id
# }

# resource "aws_apigatewayv2_stage" "default_stage" {
#   api_id = aws_apigatewayv2_api.http_api.id
#   name   = "prod"
#   auto_deploy = true
# }


/// HTTPS LAMBDA
resource "aws_api_gateway_resource" "https_lambda_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "redirect"
}

resource "aws_api_gateway_method" "https_lambda_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.https_lambda_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "https_lambda_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.https_lambda_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "https_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.https_lambda_resource.id
  http_method             = aws_api_gateway_method.https_lambda_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.https_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "https_lambda_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.https_lambda_resource.id
  http_method = aws_api_gateway_method.https_lambda_options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "https_lambda_options_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.https_lambda_resource.id
  http_method = aws_api_gateway_method.https_lambda_options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "https_lambda_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.https_lambda_resource.id
  http_method = aws_api_gateway_method.https_lambda_options_method.http_method
  status_code = aws_api_gateway_method_response.https_lambda_options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_method_response" "https_lambda_get_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.https_lambda_resource.id
  http_method = aws_api_gateway_method.https_lambda_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.https_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*/*"
}

# resource "aws_apigatewayv2_integration" "https_lambda_integration" {
#   api_id                 = aws_apigatewayv2_api.http_api.id
#   integration_type       = "AWS_PROXY"
#   integration_uri        = aws_lambda_function.https_lambda.invoke_arn
#   payload_format_version = "2.0"
# }

# resource "aws_apigatewayv2_route" "https_redirect_route" {
#   api_id    = aws_apigatewayv2_api.http_api.id
#   route_key = "GET /redirect"
#   target    = "integrations/${aws_apigatewayv2_integration.https_lambda_integration.id}"
# }

# resource "aws_lambda_permission" "https_lambda_permission" {
#   statement_id  = "AllowHttpApiInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.https_lambda.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
# }


/// LAMBDA PARA SUBIR DATA DE CSV A DYNAMO
resource "aws_api_gateway_resource" "upload_data_lambda_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "upload_lambda_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.upload_data_lambda_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_method" "cors_options_upload" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.upload_data_lambda_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.upload_data_lambda_resource.id
  http_method             = aws_api_gateway_method.upload_lambda_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload_data_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "cors_integration_upload" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.upload_data_lambda_resource.id
  http_method = aws_api_gateway_method.cors_options_upload.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "upload_lambda_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.upload_data_lambda_resource.id
  http_method = aws_api_gateway_method.upload_lambda_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Methods"     = true
    "method.response.header.Access-Control-Allow-Headers"     = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "cors_method_response_upload" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.upload_data_lambda_resource.id
  http_method = aws_api_gateway_method.cors_options_upload.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = true
    "method.response.header.Access-Control-Allow-Methods"     = true
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "upload_lambda_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.upload_data_lambda_resource.id
  http_method = aws_api_gateway_method.upload_lambda_method.http_method
  status_code = aws_api_gateway_method_response.upload_lambda_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = "'http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com'"
    "method.response.header.Access-Control-Allow-Methods"     = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }

  depends_on = [
    aws_api_gateway_integration.upload_lambda_integration
  ]
}

resource "aws_api_gateway_integration_response" "cors_integration_response_upload" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.upload_data_lambda_resource.id
  http_method = aws_api_gateway_method.cors_options_upload.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods"     = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"      = "'http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }

  depends_on = [
    aws_api_gateway_integration.cors_integration_upload
  ]
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_data_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*/*"
}

# resource "aws_apigatewayv2_integration" "upload_lambda_integration" {
#   api_id                  = aws_apigatewayv2_api.http_api.id
#   integration_type        = "AWS_PROXY"
#   integration_uri         = aws_lambda_function.upload_data_lambda.invoke_arn
#   payload_format_version  = "2.0"
# }

# resource "aws_apigatewayv2_route" "upload_route" {
#   api_id    = aws_apigatewayv2_api.http_api.id
#   route_key = "POST /upload"
#   target    = "integrations/${aws_apigatewayv2_integration.upload_lambda_integration.id}"
# }

# resource "aws_apigatewayv2_route" "cors_options_route" {
#   api_id    = aws_apigatewayv2_api.http_api.id
#   route_key = "OPTIONS /upload"
#   target    = "integrations/${aws_apigatewayv2_integration.upload_lambda_integration.id}"
# }

# resource "aws_lambda_permission" "upload_data_lambda_permission" {
#   statement_id  = "AllowHttpApiInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.upload_data_lambda.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
# }


/// FRONT TO BACK LAMBDA
resource "aws_api_gateway_resource" "optimization_lambda_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "optimize"
}

resource "aws_api_gateway_method" "optimization_lambda_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "optimization_lambda_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "optimization_lambda_integration" {
  for_each = {
    "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
    "us-east-1b" = element(module.vpc.private_subnets, 1)
  }

  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method             = aws_api_gateway_method.optimization_lambda_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.optimization_lambda[each.key].invoke_arn

  depends_on = [aws_lambda_permission.optimization_lambda_permission]
}

resource "aws_api_gateway_integration" "optimization_lambda_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method = aws_api_gateway_method.optimization_lambda_options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "optimization_lambda_post_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method = aws_api_gateway_method.optimization_lambda_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Headers"     = true
    "method.response.header.Access-Control-Allow-Methods"     = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_method_response" "optimization_lambda_cors_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method = aws_api_gateway_method.optimization_lambda_options_method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "optimization_lambda_post_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method = aws_api_gateway_method.optimization_lambda_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = "'http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com'"
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "method.response.header.Access-Control-Allow-Methods"     = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }

  depends_on = [
    aws_api_gateway_method_response.optimization_lambda_post_response,
    aws_api_gateway_integration.optimization_lambda_integration
  ]
}

resource "aws_api_gateway_integration_response" "optimization_lambda_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method = aws_api_gateway_method.optimization_lambda_options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com'"
  }

  depends_on = [
    aws_api_gateway_integration.optimization_lambda_cors_integration,
    aws_api_gateway_method.optimization_lambda_options_method
  ]
}

resource "aws_lambda_permission" "optimization_lambda_permission" {
  for_each = {
    "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
    "us-east-1b" = element(module.vpc.private_subnets, 1)
  }

  statement_id  = "AllowSendInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.optimization_lambda[each.key].function_name
  principal     = "apigateway.amazonaws.com"
}

# resource "aws_apigatewayv2_integration" "send_lambda_integration" {
#   for_each = {
#     "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
#     "us-east-1b" = element(module.vpc.private_subnets, 1)
#   }

#   api_id           = aws_apigatewayv2_api.http_api.id
#   integration_type = "AWS_PROXY"
#   integration_uri  = aws_lambda_function.optimization_lambda[each.key].invoke_arn
#   payload_format_version = "2.0"
# }

# resource "aws_apigatewayv2_route" "send_route" {
#   for_each = {
#     "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
#     "us-east-1b" = element(module.vpc.private_subnets, 1)
#   }

#   api_id    = aws_apigatewayv2_api.http_api.id
#   route_key = "POST /send"
#   target    = "integrations/${aws_apigatewayv2_integration.send_lambda_integration[each.key].id}"
# }

# resource "aws_lambda_permission" "optimization_lambda_permission" {
#   for_each = {
#     "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
#     "us-east-1b" = element(module.vpc.private_subnets, 1)
#   }

#   statement_id  = "AllowHttpApiInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.optimization_lambda[each.key].function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
# }



/// MODELO DE OPTIMIZACIÓN EN EC2
# resource "aws_api_gateway_resource" "optimize_resource" {
#   rest_api_id = aws_api_gateway_rest_api.api_gateway.id
#   parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
#   path_part   = "optimize"
# }

# resource "aws_api_gateway_method" "post_optimize" {
#   rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
#   resource_id   = aws_api_gateway_resource.optimize_resource.id
#   http_method   = "POST"
#   authorization = "NONE"
# }

# resource "aws_api_gateway_method_response" "post_optimize_response" {
#   rest_api_id = aws_api_gateway_rest_api.api_gateway.id
#   resource_id = aws_api_gateway_resource.optimize_resource.id
#   http_method = aws_api_gateway_method.post_optimize.http_method
#   status_code = "200"
# }

# resource "aws_api_gateway_integration" "optimize_integration" {
#   for_each = {
#     "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
#     "us-east-1b" = element(module.vpc.private_subnets, 1)
#   }

#   rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
#   resource_id             = aws_api_gateway_resource.optimize_resource.id
#   http_method             = aws_api_gateway_method.post_optimize.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = aws_lambda_function.optimization_lambda[each.key].invoke_arn

#   depends_on = [aws_lambda_permission.optimize_permission]
# }

# resource "aws_api_gateway_method" "options_optimize" {
#   rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
#   resource_id   = aws_api_gateway_resource.optimize_resource.id
#   http_method   = "OPTIONS"
#   authorization = "NONE"
# }

# resource "aws_api_gateway_method_response" "options_response" {
#   rest_api_id = aws_api_gateway_rest_api.api_gateway.id
#   resource_id = aws_api_gateway_resource.optimize_resource.id
#   http_method = "OPTIONS"
#   status_code = "200"

#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Origin"      = true
#     "method.response.header.Access-Control-Allow-Methods"     = true
#     "method.response.header.Access-Control-Allow-Headers"     = true
#   }
# }

# resource "aws_api_gateway_integration_response" "options_integration_response" {
#   rest_api_id = aws_api_gateway_rest_api.api_gateway.id
#   resource_id = aws_api_gateway_resource.optimize_resource.id
#   http_method = aws_api_gateway_method.post_optimize.http_method
#   status_code = "200"

#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Origin"      = "'*'"
#     "method.response.header.Access-Control-Allow-Methods"     = "'OPTIONS,POST'"
#     "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
#   }
# }

# resource "aws_lambda_permission" "optimize_permission" {
#   for_each = {
#     "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
#     "us-east-1b" = element(module.vpc.private_subnets, 1)
#   }

#   statement_id  = "AllowOptimizeInvocation"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.optimization_lambda[each.key].function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "arn:aws:execute-api:us-east-1:964072067438:${aws_api_gateway_rest_api.api_gateway.id}/*/POST/optimize"
# }

/// GENERAL
resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  depends_on = [
    aws_api_gateway_method.https_lambda_method,
    aws_api_gateway_integration.https_lambda_integration,
    aws_api_gateway_integration.upload_lambda_integration,
    aws_api_gateway_integration.cors_integration_upload,
    aws_api_gateway_integration_response.cors_integration_response_upload,
    aws_api_gateway_integration.optimization_lambda_integration,
    aws_api_gateway_integration.optimization_lambda_cors_integration,
    aws_api_gateway_integration_response.optimization_lambda_cors_integration_response,
    # aws_api_gateway_integration.optimize_integration,
    # aws_api_gateway_integration_response.options_integration_response
  ]

  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = "prod"
}

output "api_gateway_url" {
  value       = aws_api_gateway_deployment.api_gateway_deployment.invoke_url
  description = "Base URL for the OptiPC API Gateway"
}


   ####################################
########       VPC ENDPOINT       ########
   ####################################

resource "aws_vpc_endpoint" "ssm_endpoint" {
  for_each = {
    "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea un VPC endpoint para la private-subnet de cada AZ
    "us-east-1b" = element(module.vpc.private_subnets, 1)
  }
  
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-1.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [each.value]
}

resource "aws_vpc_endpoint" "dynamodb_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}


   ####################################
########          COGNITO         ########
   ####################################

resource "aws_cognito_user_pool" "user_pool" {
  name = "optipc-user-pool"

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  # Configuración de la política de contraseñas
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Configuración del correo electrónico para la verificación del usuario
  auto_verified_attributes = ["email"]

  # Configuración de atributos requeridos
  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = false
  }

  schema {
    attribute_data_type = "String"
    name                = "name"
    required            = true
    mutable             = true
  }

  # Configuración del mensaje de bienvenida o verificación
  email_verification_subject = "Verifica tu cuenta"
  email_verification_message = "Por favor, haz clic en el siguiente enlace para verificar tu cuenta: {####}"
}

resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain      = var.domain
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "optipc_pool_client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  prevent_user_existence_errors = "ENABLED"
  supported_identity_providers = ["COGNITO"]

  generate_secret = false
  allowed_oauth_flows       = ["code", "implicit"]
  allowed_oauth_scopes      = ["phone", "email", "openid", "profile"]
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
  ]
  callback_urls = ["https://${aws_api_gateway_rest_api.api_gateway.id}.execute-api.us-east-1.amazonaws.com/prod/redirect"]
  logout_urls   = ["https://${aws_api_gateway_rest_api.api_gateway.id}.execute-api.us-east-1.amazonaws.com/prod/redirect"]
  # callback_urls = ["https://${aws_apigatewayv2_api.http_api.id}.execute-api.us-east-1.amazonaws.com/prod/redirect"]
  # logout_urls   = ["https://${aws_apigatewayv2_api.http_api.id}.execute-api.us-east-1.amazonaws.com/prod/redirect"]
  
  allowed_oauth_flows_user_pool_client = true
}

output "user_pool_client_id" { # muestra el clientId para el pool de cognito (necesario para pasarselo a la url del front)
  value = aws_cognito_user_pool_client.user_pool_client.id
}

# output "api_gateway_id" {
#   value = aws_api_gateway_rest_api.api_gateway.id
# }

resource "aws_cognito_user_group" "admin_group" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  name         = "Administradores"
}

# Crear usuarios administradores
resource "aws_cognito_user" "admin_user_1" {
  username   = "admin1@example.com"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  temporary_password = "Admin@1234"
  attributes = {
    name = "admin1",
    email = "admin1@example.com"
  }
  depends_on = [aws_cognito_user_group.admin_group]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cognito_user" "admin_user_2" {
  username   = "admin2@example.com"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  temporary_password = "Admin@1234"
  attributes = {
    name = "admin2",
    email = "admin2@example.com"
  }
  depends_on = [aws_cognito_user_group.admin_group]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cognito_user_in_group" "admin_membership_1" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  username     = aws_cognito_user.admin_user_1.username
  group_name   = aws_cognito_user_group.admin_group.name
}

resource "aws_cognito_user_in_group" "admin_membership_2" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  username     = aws_cognito_user.admin_user_2.username
  group_name   = aws_cognito_user_group.admin_group.name
}

resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name = "identity_pool"
  allow_unauthenticated_identities = true
}

resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name             = "cognito-authorizer"
  rest_api_id      = aws_api_gateway_rest_api.api_gateway.id
  authorizer_uri   = "arn:aws:cognito-idp:us-east-1:${data.aws_caller_identity.current.account_id}:userpool/${aws_cognito_user_pool.user_pool.id}"
  type             = "COGNITO_USER_POOLS"
  identity_source  = "method.request.header.Authorization"
  provider_arns    = [aws_cognito_user_pool.user_pool.arn]
}

# resource "aws_iam_policy" "secrets_ssm_access_policy" {
#   name        = "secrets_ssm_access_policy"
#   description = "Permite acceso a Secrets Manager y Parameter Store para el frontend"

#   policy = jsonencode({
#     "Version": "2012-10-17",
#     "Statement": [
#       {
#         "Effect": "Allow",
#         "Action": [
#           "secretsmanager:GetSecretValue",
#           "ssm:GetParameter"
#         ],
#         "Resource": [
#           "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:myapp/secrets",
#           "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/myapp/domain"
#         ]
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "attach_secrets_ssm_policy" {
#   role       = aws_iam_role.frontend_role.name
#   policy_arn = aws_iam_policy.secrets_ssm_access_policy.arn
# }

# resource "aws_iam_policy" "dynamodb_access" {
#   name        = "DynamoDBAccess"
#   description = "Política para acceder a DynamoDB"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "dynamodb:PutItem",
#           "dynamodb:GetItem",
#           "dynamodb:UpdateItem",
#           "dynamodb:DeleteItem",
#           "dynamodb:Scan",
#           "dynamodb:Query"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "attach_dynamodb_access_to_admin_group" {
#   policy_arn = aws_iam_policy.dynamodb_access.arn
#   role       = aws_cognito_user_group.admin_group.id
# }



# ESTO CREA LOS DOS GRUPOS DE USUARIOS DE COGNITO (REGULARES Y ADMINISTRADORES). FALTA DARLE ACCESO A LA DB Y A LA CARGA DE DATOS SOLO A LOS ADMINISTRADORES.

   ####################################
########          DATA S3         ########
   ####################################

# resource "aws_s3_bucket" "csv_bucket" {
#   bucket = var.csv_bucket_name

#   tags = {
#     Name = var.csv_bucket_name
#     Environment = "dev"
#   }
# }

# # Opcional: Habilitar la versión del archivo para el control de versiones (opcional)
# resource "aws_s3_bucket_versioning" "csv_bucket_versioning" {
#   bucket = aws_s3_bucket.csv_bucket.bucket

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_object" "csv_file" {
#   bucket = aws_s3_bucket.csv_bucket.bucket
#   key    = "componentes_final.csv"
#   source = "./data/componentes_final.csv"
# }


   ####################################
########        FRONTEND S3       ########
   ####################################

# http://optipc-front-storage-tom.s3-website-us-east-1.amazonaws.com
resource "aws_s3_bucket" "frontend_bucket"{
    bucket = var.bucket_name

    tags={
        Name = var.bucket_name
        Author = "G32024Q2"
    }
}

# Configuración del alojamiento de sitios web estáticos
resource "aws_s3_bucket_website_configuration" "frontend_bucket_website" {
  bucket = aws_s3_bucket.frontend_bucket.bucket

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
}

resource "aws_s3_bucket_cors_configuration" "frontend_cors" {
  bucket = aws_s3_bucket.frontend_bucket.id

  cors_rule {
    allowed_methods = ["GET", "POST", "PUT"]
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


   ####################################
########       EC2 KEY PAIR       ########
   ####################################

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "ec2_key_pair"
  public_key = file("~/.ssh/id_rsa.pub")
}

   ####################################
########     BASTION HOST EC2     ########
   ####################################

resource "aws_security_group" "bastion_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Limitar a tu IP para mayor seguridad
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# EC2 Bastion Host en la subnet pública
resource "aws_instance" "bastion" {
  for_each = {
    "us-east-1a" = element(module.vpc.public_subnets, 0) # Se crea una EC2 para la public-subnet de cada AZ
    "us-east-1b" = element(module.vpc.public_subnets, 1)
  }

  ami           = data.aws_ami.ec2_ami.id
  instance_type = "t2.micro"
  subnet_id     = each.value
  availability_zone = each.key
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "BastionHost-${each.key}"
  }

  key_name = aws_key_pair.ec2_key_pair.key_name
}


   ####################################
########        BACKEND EC2       ########
   ####################################

resource "aws_security_group" "private_ec2_sg" {
  vpc_id = module.vpc.vpc_id

  # permite el ingreso de IPS que accedan al Bastion Host
  ingress {
    description = "Allow Bastion Host Traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # permite que salga todo
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "backend_ec2" {
  for_each = {
    "us-east-1a" = element(module.vpc.private_subnets, 2) # Se crea una EC2 para la segunda private-subnet de cada AZ (dejo las que tienen VPC endpoint para alojar las lambdas)
    "us-east-1b" = element(module.vpc.private_subnets, 3)
  }

  ami           = data.aws_ami.ec2_ami.id
  instance_type = "t2.micro"
  subnet_id     = each.value
  availability_zone = each.key
  vpc_security_group_ids = [aws_security_group.private_ec2_sg.id]

  tags = {
    Name = "OptimizationBackend-${each.key}"
  }

  key_name = aws_key_pair.ec2_key_pair.key_name
}


   ###############################
########    ARCHIVO LOCAL    ########
   ###############################
// Para pasar variables al front

resource "local_file" "config_file" {
  filename = "./front/config.json"

  content = jsonencode({
    domain                = var.domain,
    user_pool_client_id   = aws_cognito_user_pool_client.user_pool_client.id
    api_gateway_id        = aws_api_gateway_rest_api.api_gateway.id
    # api_gateway_id        = aws_apigatewayv2_api.http_api.id
    user_pool_id          = aws_cognito_user_pool.user_pool.id
    website_endpoint      = aws_s3_bucket.frontend_bucket.website_endpoint
  })
}

resource "aws_s3_object" "config_file" {
  bucket = aws_s3_bucket.frontend_bucket.bucket
  key    = "config.json"
  source = "./front/config.json"
  content_type = "application/json"
}

output "identity_pool_id" {
  value = aws_cognito_identity_pool.identity_pool.id
}


   ###############################
########   SECRET MANAGER   ########
   ###############################

# resource "aws_secretsmanager_secret" "app_secrets" {
#   name = "myapp/secrets"
#   description = "Secrets for my app"
# }

# resource "aws_secretsmanager_secret_version" "app_secrets_version" {
#   secret_id     = aws_secretsmanager_secret.app_secrets.id
#   secret_string = jsonencode({
#     user_pool_client_id     = aws_cognito_user_pool_client.user_pool_client.id
#     # bucket_url    = aws_s3_bucket.frontend_bucket.website_endpoint
#     identity_pool_id = aws_cognito_identity_pool.identity_pool.id
#   })
# }


   ###############################
########   PARAMETER STORE   ########
   ###############################

# resource "aws_ssm_parameter" "parameters" {
#   for_each = {
#     "redirect_uri" = "http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com"
#     "domain"       = var.domain
#     "bucket_name"       = var.bucket_name
#     "user_pool_client_id"       = aws_cognito_user_pool_client.user_pool_client.id
#   }

#   name  = "/myapp/${each.key}"
#   type  = "String"
#   value = each.value
# }









# CHEQUEAR
# 1. SECURITY GROUPS
# 2. COGNITO Y ¿SECRET MANAGER?
# 3. DATASOURCES DE AZs/AMIs
# 4. MODULO INTERNO (PENSAR DE QUÉ)
# 5. ARCHIVO VARIABLES


# LEVANTAR
# 1. EC2 PRIVADA CON MODELO DE OPTIMIZACIÓN --> CONECTAR
# 2. LAMBDAS PARA LLEVAR Y TRAER LA INFO
# 3. PATRONES DE ACCESO DE DYNAMODB
    # CARGAR DATA DESDE EL FRONT A LA DB (CAMBIOS EN FRONT, GESTION USUARIOS)
    # SESIONES DE USUARIOS, INGRESAR CON USUARIO Y CONTRASEÑA (CAMBIOS EN FRONT, GESTION USUARIOS, RECUERDO)
    # GUARDAR CONFIGURACIONES DE PC EN MI HISTORIAL DE USUARIO (CAMBIOS EN FRONT, GESTION USUARIOS, RECUERDO)
    # PUBLICAR CONFIGURACIONES DE PC EN FORO (CAMBIOS EN FRONT, GESTION USUARIOS, RECUERDO)
# 4. CAMBIAR EL FRONT



# FLUJO DE CÓDIGO
# 1. terraform init
# 2. terraform plan
# 3. terraform apply --> yes
# 4. OBTENER PUBLIC IP (BASTION): aws ec2 describe-instances --filters "Name=tag:Name,Values=BastionHost*" --query "Reservations[*].Instances[*].[InstanceId, PublicIpAddress]" --output table
# 5. OBTENER PRIVATE IP (EC2): aws ec2 describe-instances --filters "Name=tag:Name,Values=OptimizationBackend*" --query "Reservations[*].Instances[*].[InstanceId, PrivateIpAddress]" --output table
# 6. SUBIR A BASTION LA KEY-PAIR: scp -i "C:/Users/Usuario/.ssh/id_rsa" -o StrictHostKeyChecking=no C:/Users/Usuario/.ssh/id_rsa ec2-user@IP_PUBLICA_EC2:~/
# 7. CONECTARME AL BASTION: ssh -i "C:/Users/Usuario/.ssh/id_rsa" ec2-user@IP_PUBLICA_EC2
# 8. CHEQUEAR QUE BASTION CONTENGA LA KEY-PAIR: ls
# 9. CAMBIAR PERMISOS DE ACCESO A LA KEY-PAIR: chmod 400 id_rsa
# 10. CONECTARME AL BACKEND: ssh -i id_rsa ec2-user@IP_PRIVADA_EC2
# 11. exit
# 12. exit
# 13. terraform destroy --> yes