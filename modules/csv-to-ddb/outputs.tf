output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB creada"
  value       = aws_dynamodb_table.my_table.name
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 que almacena el archivo CSV"
  value       = aws_s3_bucket.csv_bucket.bucket
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda que carga los datos"
  value       = aws_lambda_function.upload_csv_lambda.function_name
}
