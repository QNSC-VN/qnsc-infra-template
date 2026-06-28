terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "qnsc-tofu-state"
    key            = "__PRODUCT__/develop/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "qnsc-tofu-locks"
  }
}

provider "aws" {
  region = "ap-southeast-1"
  default_tags {
    tags = {
      Project     = "__PRODUCT__"
      Environment = "develop"
      ManagedBy   = "opentofu"
    }
  }
}

data "aws_caller_identity" "current" {}

# ── Read shared layer outputs (OIDC ARN, KMS ARN, artifacts bucket) ───────────
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "qnsc-tofu-state"
    key    = "__PRODUCT__/shared/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

locals {
  env         = "develop"
  name        = "__PRODUCT__-develop"
  region      = "ap-southeast-1"
  azs         = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  kms_key_arn = data.terraform_remote_state.shared.outputs.kms_key_arn
}

# ── Networking ────────────────────────────────────────────────────────────────
# Example of composing a shared module. Add the modules this product needs
# (rds, ecs-cluster, ecs-service, messaging, secrets, cdn, waf, …) below.
module "network" {
  source = "git::https://github.com/QNSC-VN/qnsc-tf-modules.git//modules/network?ref=network-v1.0.0"

  name                 = local.name
  region               = local.region
  azs                  = local.azs
  vpc_cidr             = "10.40.0.0/16"
  public_subnet_cidrs  = ["10.40.0.0/24", "10.40.1.0/24", "10.40.2.0/24"]
  private_subnet_cidrs = ["10.40.10.0/24", "10.40.11.0/24", "10.40.12.0/24"]
  data_subnet_cidrs    = ["10.40.20.0/24", "10.40.21.0/24", "10.40.22.0/24"]
  multi_az_nat         = false # single NAT in develop to save cost
  enable_flow_logs     = true
  tags                 = { Environment = local.env }
}

# TODO: add the rest of this product's stack here.
# See rally-infra / opshub-infra live/develop for full worked examples.
