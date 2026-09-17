# 🚀 Infraestructura Inmutable en AWS con Terraform y GitHub Actions

Este repositorio contiene la configuración de Infraestructura como Código (IaC) para desplegar una arquitectura web de alta disponibilidad en AWS. El aprovisionamiento está 100% automatizado mediante Terraform y pipelines de GitHub Actions.

## 🏗️ Arquitectura del Proyecto

El proyecto despliega la siguiente pila tecnológica en AWS:

- **Red (VPC):** Virtual Private Cloud con subredes públicas y privadas distribuidas en múltiples zonas de disponibilidad (Multi-AZ).
- **Balanceador de Carga (ALB):** Application Load Balancer en subredes públicas para distribuir el tráfico HTTP entrante.
- **Computación (ASG):** Auto Scaling Group en subredes privadas, ejecutando instancias EC2 (Amazon Linux) con servidores web.
- **Base de Datos (RDS):** Instancia de base de datos MySQL en la capa privada de datos.
- **Estado Remoto:** El `tfstate` se gestiona de forma centralizada y segura utilizando Amazon S3 y el bloqueo de estado mediante Amazon DynamoDB.

## ⚙️ Requisitos Previos

Antes de ejecutar o modificar este proyecto, asegúrate de tener:

1. Una cuenta de **AWS** activa.
2. Un bucket de **Amazon S3** creado para almacenar el estado de Terraform.
3. Una tabla de **Amazon DynamoDB** creada para el bloqueo del estado (ej. `terraform-state-lock` con Partition Key `LockID` de tipo String).
4. Credenciales de AWS configuradas en los secretos de este repositorio de GitHub:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

## 📂 Estructura del Repositorio

```text
.
├── .github/workflows/
│   ├── pr-plan.yml       # Ejecuta validaciones, tfsec y terraform plan en los PRs
│   └── main-apply.yml    # Ejecuta terraform apply al fusionar con main (requiere aprobación)
├── backend.tf            # Configuración de S3 y DynamoDB para el tfstate
├── main.tf               # Módulos principales (VPC, ALB, ASG, RDS)
├── provider.tf           # Configuración del proveedor de AWS
├── variables.tf          # Variables de entrada para personalización
└── outputs.tf            # Valores de salida (DNS del ALB, Endpoint de RDS, etc.)
```

## 🔄 Integración y Despliegue Continuo (CI/CD)

El ciclo de vida de la infraestructura está gestionado por GitHub Actions:

1. **Pull Request (CI):** Al abrir un PR hacia la rama `main`, se activa un workflow que formatea el código (`terraform fmt`), lo valida, realiza un análisis de seguridad estática (`tfsec`) y genera un plan de ejecución (`terraform plan`).
2. **Merge a Main (CD):** Al aprobar y fusionar el PR, se activa un segundo workflow que requiere **aprobación manual** (mediante entornos de GitHub). Una vez aprobado, ejecuta `terraform apply` para desplegar los cambios en AWS de manera inmutable.

## 🚀 Uso Manual (Local)

Si deseas probar la infraestructura desde tu equipo local:

1. Clona el repositorio.
2. Inicializa Terraform: `terraform init`
3. Revisa los cambios a aplicar: `terraform plan`
4. Aplica la infraestructura: `terraform apply`
5. Para destruir los recursos: `terraform destroy`