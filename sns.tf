module "sns" {
  source      = "./modulos/SNS"
  topic_name  = var.topic_name
  subscribers = var.subscribers
}