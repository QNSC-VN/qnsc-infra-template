output "ecr_repository_urls" {
  value       = module.ecr.repository_urls
  description = "Map of ECR repo name → URL."
}

output "deploy_role_arns" {
  value       = module.iam_oidc.deploy_role_arns
  description = "Per-env OIDC roles assumed by CI to deploy the API/worker."
}

output "infra_apply_role_arn" {
  value       = module.iam_oidc.infra_apply_role_arn
  description = "OIDC role assumed by the infra apply pipeline."
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

# Cloudflare singletons — one source of truth in qnsc-infra bootstrap, re-exported
# so env stacks read the zone ID / IP ranges from _shared (like kms_key_arn),
# never as a per-stack input. try(...) keeps this stack applying before qnsc-infra
# publishes the Cloudflare outputs.
output "cloudflare_zone_id" {
  value       = try(data.terraform_remote_state.platform.outputs.cloudflare_zone_id, "")
  description = "qnsc.vn Cloudflare zone ID from qnsc-infra (empty until published)."
}

output "cloudflare_ipv4" {
  value       = try(data.terraform_remote_state.platform.outputs.cloudflare_ipv4, [])
  description = "Cloudflare IPv4 CIDR ranges from qnsc-infra (empty until published)."
}
