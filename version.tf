terraform {
    required_providers {
      klayers = {
        version = "~> 1.0.0"
        source  = "ldcorentin/klayer"
      }
      aws = {
        version = ">= 2.7.0"
        source = "hashicorp/aws"
      }
    }
}