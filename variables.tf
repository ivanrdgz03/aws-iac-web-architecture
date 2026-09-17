variable "aws_region" {
  description = "Región de AWS para el despliegue"
  type        = string
  default     = "us-east-1"
}
variable "db_username" {
  description = "Usuario administrador de la base de datos"
  type        = string
  default     = "admin"
  sensitive   = true # Esto evita que Terraform lo imprima en los logs de la consola
}