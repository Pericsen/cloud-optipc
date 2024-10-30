variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "table_name" {
  description = "Nombre de la tabla DynamoDB"
  type        = string
  default = "componentes-nic"
}

variable "hash_key" {
  description = "Clave de partición de la tabla DynamoDB"
  type        = string
  default     = "id"
}

variable "csv_file" {
  description = "Ruta local del archivo CSV a cargar"
  type        = string
  default = "C:/CLOUD/cloud-optipc/modules/csv-to-ddb/componentes_final.csv"
}

variable "lambda_timeout" {
  description = "Tiempo máximo de ejecución de Lambda en segundos"
  type        = number
  default     = 60
}

variable "lambda_memory" {
  description = "Memoria asignada a la función Lambda en MB"
  type        = number
  default     = 128
}
