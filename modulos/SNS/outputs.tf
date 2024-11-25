output "sns_topic_arn" {
  description = "ARN del topic SNS creado"
  value       = aws_sns_topic.sns_topic.arn
}
