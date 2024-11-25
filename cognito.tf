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
  
  allowed_oauth_flows_user_pool_client = true
}


output "identity_pool_id" {
  value = aws_cognito_identity_pool.identity_pool.id
}

output "user_pool_client_id" { # muestra el clientId para el pool de cognito (necesario para pasarselo a la url del front)
  value = aws_cognito_user_pool_client.user_pool_client.id
}


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