variable "domain" {
  type = string
  description = "El dominio de la aplicación"
}

variable "bucket_name" {
  type = string
  description = "Nombre del Bucket del Front"
}

variable "topic_name" {
  description = "El nombre del topic SNS"
  type        = string
}

variable "subscribers" {
  description = "Lista de emails que se suscriben al topic"
  type        = list(string)
}