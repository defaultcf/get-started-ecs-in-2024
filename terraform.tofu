terraform {
  required_version = "1.8.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.62.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project = "defaultcf/get-started-ecs-in-2024"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
}
