terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "qnsc-tofu-state"
    key            = "__PRODUCT__/shared/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "qnsc-tofu-locks"
  }
}

provider "aws" {
  region = "ap-southeast-1"
  default_tags {
    tags = {
      Project   = "__PRODUCT__"
      Scope     = "shared"
      ManagedBy = "opentofu"
    }
  }
}

variable "github_org" {
  type        = string
  default     = "QNSC-VN"
  description = "GitHub org/owner that hosts the __PRODUCT__ repositories."
}

# ── Platform remote state (OIDC provider ARN, KMS, artifacts bucket) ──────────
# Provided by qnsc-infra/live/bootstrap (the account-level singletons).
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "qnsc-tofu-state"
    key    = "platform/bootstrap/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "aws_caller_identity" "current" {}

# ── Container registries ──────────────────────────────────────────────────────
# Add/remove repos to match what this product builds.
module "ecr" {
  source           = "git::https://github.com/QNSC-VN/qnsc-tf-modules.git//modules/ecr?ref=ecr-v1.0.0"
  repository_names  = ["__PRODUCT__-api", "__PRODUCT__-worker"]
  image_tag_mutability = "MUTABLE"
  kms_key_arn       = data.terraform_remote_state.platform.outputs.kms_key_arn
  tags              = { Scope = "shared" }
}

# ── GitHub OIDC deploy roles (deploy per-env, ecr-push, infra plan/apply) ─────
module "iam_oidc" {
  source            = "git::https://github.com/QNSC-VN/qnsc-tf-modules.git//modules/iam-oidc?ref=iam-oidc-v1.1.0"
  product           = "__PRODUCT__"
  github_org        = var.github_org
  oidc_provider_arn = data.terraform_remote_state.platform.outputs.oidc_provider_arn

  environments = {
    develop = {
      allowed_subjects = [
        "repo:${var.github_org}/__PRODUCT__-api:ref:refs/heads/main",
        "repo:${var.github_org}/__PRODUCT__-api:environment:develop",
      ]
    }
    production = {
      allowed_subjects = [
        "repo:${var.github_org}/__PRODUCT__-api:ref:refs/heads/main",
        "repo:${var.github_org}/__PRODUCT__-api:ref:refs/tags/v*",
      ]
    }
  }

  app_repo_names         = ["__PRODUCT__-api"]
  infra_repo_name        = "__PRODUCT__-infra"
  ecr_repository_pattern = "__PRODUCT__-*"
  ecs_passrole_pattern   = "__PRODUCT__-*"
  tags                   = { Scope = "shared" }
}

# ── GitHub OIDC deploy roles for the web SPA (S3 + CloudFront) ─────────────────
# Remove this whole block if the product has no web frontend.
locals {
  web_deploy_envs = {
    develop = {
      allowed_subjects = ["repo:${var.github_org}/__PRODUCT__-web:ref:refs/heads/main"]
      s3_bucket        = "__PRODUCT__-web-develop"
    }
    production = {
      allowed_subjects = [
        "repo:${var.github_org}/__PRODUCT__-web:ref:refs/heads/main",
        "repo:${var.github_org}/__PRODUCT__-web:ref:refs/tags/v*",
      ]
      s3_bucket = "__PRODUCT__-web-prod"
    }
  }
}

resource "aws_iam_role" "web_deploy" {
  for_each = local.web_deploy_envs

  name        = "__PRODUCT__-github-web-deploy-${each.key}"
  description = "Assumed by GitHub Actions to deploy __PRODUCT__-web to ${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.terraform_remote_state.platform.outputs.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = each.value.allowed_subjects }
      }
    }]
  })

  tags = { Scope = "shared", Environment = each.key }
}

resource "aws_iam_role_policy" "web_deploy" {
  for_each = local.web_deploy_envs

  name = "__PRODUCT__-web-deploy-${each.key}"
  role = aws_iam_role.web_deploy[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Sync"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${each.value.s3_bucket}",
          "arn:aws:s3:::${each.value.s3_bucket}/*",
        ]
      },
      {
        Sid      = "CloudFrontInvalidate"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"
      },
    ]
  })
}
