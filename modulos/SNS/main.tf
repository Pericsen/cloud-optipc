# Crear el Topic de SNS
resource "aws_sns_topic" "sns_topic" {
  name = var.topic_name
}

# Crear suscripciones al Topic
resource "aws_sns_topic_subscription" "subscriptions" {
  for_each = toset(var.subscribers)

  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = each.value
}