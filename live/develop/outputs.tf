# Add outputs as you add modules, e.g.:
# output "alb_dns_name" { value = aws_lb.this.dns_name }

output "vpc_id" {
  value       = local.vpc_id
  description = "Shared platform-dev VPC ID this environment attaches to."
}
