   ####################################
########       VPC ENDPOINT       ########
   ####################################
   
resource "aws_vpc_endpoint" "api_gateway_endpoint" {
  for_each = {
    "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea un VPC endpoint para la private-subnet de cada AZ
    "us-east-1b" = element(module.vpc.private_subnets, 1)
  }

  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.us-east-1.execute-api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [each.value]
}

   ####################################
########        API GATEWAY       ########
   ####################################

resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "api-gateway"
  description = "API Gateway for Lambdas redirection"
}

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
resource "aws_api_gateway_integration" "https_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.https_lambda_resource.id
  http_method             = aws_api_gateway_method.https_lambda_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.https_lambda.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.https_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*/*"
}


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


/// OPTIMIZATION LAMBDA
resource "aws_api_gateway_resource" "optimization_lambda_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "optimization"
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

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "optimization_lambda_cors_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method = aws_api_gateway_method.optimization_lambda_options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "optimization_lambda_post_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method = aws_api_gateway_method.optimization_lambda_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = "'http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com'"
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods"     = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }

  depends_on = [
    aws_api_gateway_integration.optimization_lambda_integration
  ]
}

resource "aws_api_gateway_integration_response" "optimization_lambda_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.optimization_lambda_resource.id
  http_method = aws_api_gateway_method.optimization_lambda_options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods"     = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"      = "'http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }

  depends_on = [
    aws_api_gateway_method_response.optimization_lambda_cors_method_response,
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

  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*/*"
}

resource "aws_api_gateway_resource" "modify_lambda_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "modify"
}

resource "aws_api_gateway_method" "modify_lambda_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.modify_lambda_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "modify_lambda_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.modify_lambda_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "modify_lambda_integration" {
  for_each = {
    "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
    "us-east-1b" = element(module.vpc.private_subnets, 1)
  }

  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.modify_lambda_resource.id
  http_method             = aws_api_gateway_method.modify_lambda_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.modify_lambda[each.key].invoke_arn

  depends_on = [aws_lambda_permission.modify_lambda_permission]
}

resource "aws_api_gateway_integration" "modify_lambda_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.modify_lambda_resource.id
  http_method = aws_api_gateway_method.modify_lambda_options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "modify_lambda_post_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.modify_lambda_resource.id
  http_method = aws_api_gateway_method.modify_lambda_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Headers"     = true
    "method.response.header.Access-Control-Allow-Methods"     = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "modify_lambda_cors_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.modify_lambda_resource.id
  http_method = aws_api_gateway_method.modify_lambda_options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "modify_lambda_post_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.modify_lambda_resource.id
  http_method = aws_api_gateway_method.modify_lambda_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = "'http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com'"
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods"     = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }

  depends_on = [
    aws_api_gateway_integration.modify_lambda_integration
  ]
}

resource "aws_api_gateway_integration_response" "modify_lambda_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.modify_lambda_resource.id
  http_method = aws_api_gateway_method.modify_lambda_options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods"     = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"      = "'http://${var.bucket_name}.s3-website-us-east-1.amazonaws.com'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }

  depends_on = [
    aws_api_gateway_method_response.modify_lambda_cors_method_response,
    aws_api_gateway_integration.modify_lambda_cors_integration,
    aws_api_gateway_method.modify_lambda_options_method
  ]
}

resource "aws_lambda_permission" "modify_lambda_permission" {
  for_each = {
    "us-east-1a" = element(module.vpc.private_subnets, 0) # Se crea una Lambda para la private-subnet de cada AZ (las que tienen VPC Endpoint)
    "us-east-1b" = element(module.vpc.private_subnets, 1)
  }

  statement_id  = "AllowSendInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.modify_lambda[each.key].function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*/*"
}

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
    aws_api_gateway_integration.modify_lambda_integration,
    aws_api_gateway_integration.modify_lambda_cors_integration,
    aws_api_gateway_integration_response.modify_lambda_cors_integration_response
  ]

  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = "prod"
}

output "api_gateway_url" {
  value       = aws_api_gateway_deployment.api_gateway_deployment.invoke_url
  description = "Base URL for the OptiPC API Gateway"
}