output "alb_dns_name" {
  description = "DNS público del Application Load Balancer"
  value       = module.alb.dns_name
}

output "db_endpoint" {
  description = "Endpoint de conexión para la base de datos RDS"
  value       = module.db.db_instance_endpoint
}

output "db_secret_arn" {
  description = "ARN del secreto en AWS Secrets Manager que contiene las credenciales de la BD"
  value       = module.db.db_instance_master_user_secret_arn
}