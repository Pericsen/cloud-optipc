variable "topic_name" {
  description = "El nombre del topic SNS"
  type        = string
}

variable "subscribers" {
  description = "Lista de emails que se suscriben al topic"
  type        = list(string)
}
