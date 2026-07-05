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

# ── Read platform-dev outputs (shared VPC + RDS + Valkey for ALL products'
# develop environments — see qnsc-infra/live/platform-dev). Develop does NOT
# provision its own network/RDS/cache; it attaches to this shared stack.
# Only prod provisions its own fully-isolated infra (see live/prod/main.tf).
data "terraform_remote_state" "platform_dev" {
  backend = "s3"
  config = {
    bucket = "qnsc-tofu-state"
    key    = "platform/platform-dev/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

locals {
  env  = "develop"
  name = "__PRODUCT__-develop"

  # Shared platform-dev outputs — reused across every product's develop stack.
  vpc_id             = data.terraform_remote_state.platform_dev.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.platform_dev.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.platform_dev.outputs.private_subnet_ids
  sg_alb_id          = data.terraform_remote_state.platform_dev.outputs.sg_alb_id
  sg_app_id          = data.terraform_remote_state.platform_dev.outputs.sg_app_id
  sg_rds_id          = data.terraform_remote_state.platform_dev.outputs.sg_rds_id
  sg_cache_id        = data.terraform_remote_state.platform_dev.outputs.sg_cache_id
  rds_address        = data.terraform_remote_state.platform_dev.outputs.rds_address
  rds_port           = data.terraform_remote_state.platform_dev.outputs.rds_port
  cache_endpoint     = data.terraform_remote_state.platform_dev.outputs.cache_endpoint
  cache_port         = data.terraform_remote_state.platform_dev.outputs.cache_port

  kms_key_arn = data.terraform_remote_state.shared.outputs.kms_key_arn
}

# ── This product's own database ──────────────────────────────────────────────
# platform-dev's shared RDS instance hosts one database per product, but
# Terraform doesn't own creating it (would need the instance in a public
# subnet — see qnsc-infra/live/platform-dev/main.tf header comment for why).
# Instead, this product's migrator task creates "__PRODUCT___dev" as its
# first migration step, from inside the shared VPC. Add that step to your
# migrator's entrypoint/first migration file — see rally or opshub's migrator
# for a worked example once rally-develop is migrated onto platform-dev.

# ── Everything else: ECS cluster, ECS service(s), ALB, CDN, secrets, etc. ───
# Add the modules this product needs (ecs-cluster, ecs-service, secrets, cdn,
# messaging, waf, …), same as live/prod/main.tf, but referencing the shared
# vpc_id / *_subnet_ids / sg_*_id / rds_address / cache_endpoint locals above
# instead of provisioning a "network" module here. See rally-infra or
# opshub-infra live/develop for a full worked example of the module set
# (though those still predate the platform-dev migration as of this template
# update — check qnsc-infra/live/platform-dev's own commit for the intended
# shape if the examples haven't been migrated yet).
#
# TODO: add the rest of this product's stack here.
