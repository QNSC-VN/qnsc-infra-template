terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "qnsc-tofu-state"
    key            = "__PRODUCT__/prod/terraform.tfstate"
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
      Environment = "prod"
      ManagedBy   = "opentofu"
    }
  }
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "qnsc-tofu-state"
    key    = "__PRODUCT__/shared/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

locals {
  env         = "prod"
  name        = "__PRODUCT__-prod"
  region      = "ap-southeast-1"
  azs         = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  kms_key_arn = data.terraform_remote_state.shared.outputs.kms_key_arn
}

# ── Networking (HA NAT in prod) ───────────────────────────────────────────────
module "network" {
  source = "git::https://github.com/QNSC-VN/qnsc-tf-modules.git//modules/network?ref=network-v1.1.2"

  name                 = local.name
  region               = local.region
  azs                  = local.azs
  # __NET__ = the second octet reserved for this product-env in
  # qnsc-infra/allocations.json. init.sh replaces it; never hardcode a value
  # that collides with an existing allocation.
  vpc_cidr             = "10.__NET__.0.0/16"
  public_subnet_cidrs  = ["10.__NET__.0.0/24", "10.__NET__.1.0/24", "10.__NET__.2.0/24"]
  private_subnet_cidrs = ["10.__NET__.10.0/24", "10.__NET__.11.0/24", "10.__NET__.12.0/24"]
  data_subnet_cidrs    = ["10.__NET__.20.0/24", "10.__NET__.21.0/24", "10.__NET__.22.0/24"]
  multi_az_nat         = true # HA NAT in production
  enable_flow_logs     = true
  tags                 = { Environment = local.env }
}

# TODO: add the rest of this product's prod stack here.
# Production guidance: multi_az = true on RDS, deletion_protection = true,
# larger instance classes, longer backup retention.
