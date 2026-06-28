# Add outputs as you add modules, e.g.:
# output "alb_dns_name" { value = aws_lb.this.dns_name }
# output "rds_endpoint" { value = module.rds.endpoint }

output "vpc_id" {
  value       = module.network.vpc_id
  description = "VPC ID for this environment."
}
