locals {
  name     = "proyecto1-infra"
  vpc_cidr = "10.0.0.0/16"
}

# 1. VPC Y REDES
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr

  azs              = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24"]

  create_database_subnet_group = true
  enable_nat_gateway           = true
  single_nat_gateway           = true
}

# 2. SECURITY GROUPS (Mínimo Privilegio de Red)
# SG para el ALB y las instancias Web
module "web_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-web-sg"
  description = "Security group para la capa web (ALB y ASG)"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP web traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_rules = ["all-all"]
}

# SG exclusivo para la Base de Datos (Solo acepta de web_sg)
module "db_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-db-sg"
  description = "Security group para RDS MySQL"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 3306
      to_port                  = 3306
      protocol                 = "tcp"
      description              = "MySQL desde la capa web"
      source_security_group_id = module.web_sg.security_group_id
    }
  ]
}

# 3. BASE DE DATOS (RDS)
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${local.name}-db"

  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0"
  major_engine_version = "8.0"
  instance_class       = "db.t3.micro"

  allocated_storage = 20
  db_name           = "appdb"
  username          = var.db_username
  
  # AWS gestiona la clave y la guarda en Secrets Manager
  manage_master_user_password = true

  port                   = 3306
  multi_az               = false
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [module.db_sg.security_group_id]
  
  skip_final_snapshot = true
}

# 4. IAM PARA INSTANCIAS EC2
resource "aws_iam_policy" "db_secret_access" {
  name        = "${local.name}-db-secret-policy"
  description = "Permite acceso de lectura unicamente al secreto de la RDS"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = module.db.db_instance_master_user_secret_arn
      }
    ]
  })
}

module "ec2_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.30"

  create_role             = true
  create_instance_profile = true
  role_name               = "${local.name}-web-role"
  role_requires_mfa       = false

  trusted_role_services = ["ec2.amazonaws.com"]

  custom_role_policy_arns = [
    aws_iam_policy.db_secret_access.arn,
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

# 5. APPLICATION LOAD BALANCER (ALB)
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name    = "${local.name}-alb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  security_groups = [module.web_sg.security_group_id]

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "web_tg"
      }
    }
  }

  target_groups = {
    web_tg = {
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      vpc_id           = module.vpc.vpc_id
    }
  }
}

# 6. AUTO SCALING GROUP (ASG)
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 7.0"

  name = "${local.name}-asg"

  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = module.vpc.private_subnets
  target_group_arns   = [module.alb.target_groups["web_tg"].arn]
  security_groups     = [module.web_sg.security_group_id]

  image_id      = "ami-0c7217cdde317cfec" # Amazon Linux 2023 en us-east-1 (Revisar según región)
  instance_type = "t3.micro"
  
  create_iam_instance_profile = false
  iam_instance_profile_name   = module.ec2_iam_role.iam_instance_profile_name
  
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Despliegue Inmutable Exitoso - DevSecOps</h1>" > /var/www/html/index.html
              EOF
  )
}