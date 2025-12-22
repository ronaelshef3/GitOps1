terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # גרסה יציבה ומודרנית
    }
  }
}

provider "aws" {
  region  = "us-east-1" # המחוז שבו בחרת לעבוד
  profile = "default"   # זה הקישור לכספת המקומית שיצרת ב-aws configure
}