output "lambda_security_group_id" {
  value       = aws_security_group.lambda_sg.id
  description = "The ID of the Lambda security group"
}
