output "ecr_repository_urls" {
  value       = module.ecr.repository_urls
  description = "Map of ECR repo name → URL."
}

output "deploy_role_arn" {
  value       = module.iam_oidc.deploy_role_arn
  description = "OIDC role assumed by CI to deploy the API/worker."
}

output "web_deploy_role_arns" {
  value       = { for k, v in aws_iam_role.web_deploy : k => v.arn }
  description = "OIDC roles assumed by CI to deploy the web SPA, per env."
}

# ── Re-exported platform singletons (env stacks read these, not qnsc-infra) ───
output "kms_key_arn" {
  value       = data.terraform_remote_state.platform.outputs.kms_key_arn
  description = "Shared CMK ARN from qnsc-infra."
}

output "artifacts_bucket_name" {
  value       = data.terraform_remote_state.platform.outputs.artifacts_bucket_name
  description = "Shared artifacts bucket from qnsc-infra."
}
