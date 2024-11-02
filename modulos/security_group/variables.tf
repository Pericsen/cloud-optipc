variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where the security group will be created"
}

variable "ingress_from_port" {
  type        = number
  description = "The starting port for ingress traffic"
  default     = 0
}

variable "ingress_to_port" {
  type        = number
  description = "The ending port for ingress traffic"
  default     = 0
}

variable "ingress_protocol" {
  type        = string
  description = "Protocol for ingress traffic"
  default     = "-1"
}

variable "ingress_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks for ingress traffic"
  default     = ["10.0.0.0/16"]
}

variable "egress_from_port" {
  type        = number
  description = "The starting port for egress traffic"
  default     = 0
}

variable "egress_to_port" {
  type        = number
  description = "The ending port for egress traffic"
  default     = 0
}

variable "egress_protocol" {
  type        = string
  description = "Protocol for egress traffic"
  default     = "-1"
}

variable "egress_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks for egress traffic"
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to the security group"
  default     = {
    Terraform   = "true"
    Environment = "dev"
  }
}
