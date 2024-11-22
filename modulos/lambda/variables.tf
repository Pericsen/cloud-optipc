variable "role" {
  type        = string
  description = "The Role associated to the Lambda function"
}

variable "lambdas" {
  type        = list(object({
    name = string,
    handler = string,
    runtime = string,
    environment_variables = list(object({
      name = string,
      value = string
    }))
  }))
  description = "The list of lambda functions to create"
}
