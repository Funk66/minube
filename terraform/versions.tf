terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.25.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "minube"

    workspaces {
      name = "minube"
    }
  }
}
