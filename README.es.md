# ClaimOps Platform - Infraestructura como Código

**[English](README.md) | [Español](#espanol)**

<a name="espanol"></a>

## Descripción General

ClaimOps Platform Infrastructure es un **proyecto Terraform enfocado en estudio** que define infraestructura AWS para la aplicación ClaimOps (sistema de procesamiento de reclamos). Este proyecto demuestra prácticas profesionales de IaC con una característica crítica de seguridad: **no se crean recursos por defecto**.

### Características Clave

- ✅ **Modo Estudio**: Validar y aprender sin requerir cuenta AWS
- ✅ **Guardia de Seguridad**: `enable_resources = false` por defecto (cero recursos creados)
- ✅ **Optimizado Free Tier**: Al desplegarse, permanece dentro de los límites gratuitos de AWS
- ✅ **Seguridad de Nivel Productivo**: IAM de privilegio mínimo, encriptación, bloqueo de acceso público
- ✅ **Diseño Modular**: Separación clara de recursos IAM, S3 y DynamoDB

### Qué Define Este Proyecto

| Recurso | Propósito | Caso de Uso de Negocio |
|---------|-----------|------------------------|
| **Rol IAM** | `claimsops-app-executor` | Permisos mínimos para que la app acceda S3 y DynamoDB |
| **Bucket S3** | `claimsops-exports-{account-id}` | Almacenar reportes de reclamos, documentos y exportaciones |
| **Tabla DynamoDB** | `claimsops-audit-events` | Registrar eventos de auditoría, metadatos de reclamos (NoSQL) |

---

## Inicio Rápido

### Prerrequisitos

- Terraform >= 1.7.0 ([Descargar](https://www.terraform.io/downloads))
- Git
- **(Opcional)** Cuenta AWS con credenciales configuradas

### Instalación

```bash
# Clonar repositorio
git clone https://github.com/SvillarroelZ/ClaimOps-Platform.git
cd ClaimOps-Platform/infra/terraform

# Inicializar Terraform (descarga providers y módulos)
terraform init

# Validar configuración (NO requiere cuenta AWS)
terraform validate
```

### Modo Estudio (Sin AWS Requerido)

```bash
# Formatear código
terraform fmt -recursive

# Validar sintaxis
terraform validate

# Ver qué SE CREARÍA (requiere credenciales AWS)
terraform plan

# Resultado: "0 to add, 0 to change, 0 to destroy" 
# Porque enable_resources = false por defecto
```

### Modo Despliegue (Requiere Cuenta AWS)

⚠️ **ADVERTENCIA**: Esto crea recursos AWS reales y puede generar costos

```bash
# 1. Configurar credenciales AWS
aws configure

# 2. Crear terraform.tfvars
cp terraform.tfvars.example terraform.tfvars

# 3. Editar terraform.tfvars y establecer:
#    enable_resources = true  ← PASO CRÍTICO

# 4. Revisar plan
terraform plan

# 5. Desplegar infraestructura
terraform apply

# 6. Ver outputs
terraform output

# 7. Al terminar, destruir recursos
terraform destroy
```

---

## Estructura del Proyecto

```
infra/terraform/
├── providers.tf          # Configuración AWS provider y backend
├── variables.tf          # Variables de entrada con validaciones
├── main.tf               # Orquestación de módulos
├── outputs.tf            # Exportación de recursos
├── terraform.tfvars.example  # Plantilla de configuración
│
└── modules/
    ├── iam/              # Rol IAM para acceso de aplicación
    │   ├── main.tf       # Rol y políticas
    │   ├── variables.tf  # Entradas del módulo IAM
    │   └── outputs.tf    # Exportación ARN del rol
    │
    ├── s3/               # Bucket S3 para exportaciones
    │   ├── main.tf       # Bucket con encriptación
    │   ├── variables.tf  # Entradas del módulo S3
    │   └── outputs.tf    # Exportación nombre/ARN bucket
    │
    └── dynamodb/         # DynamoDB para eventos de auditoría
        ├── main.tf       # Tabla con streams
        ├── variables.tf  # Entradas del módulo DynamoDB
        └── outputs.tf    # Exportación nombre/ARN tabla
```

---

## Guardia de Seguridad Explicada

### Por Qué Existe `enable_resources`

Este proyecto está diseñado para **estudio y validación** sin requerir cuenta AWS. La variable `enable_resources` protege contra la creación accidental de recursos:

```hcl
# En variables.tf
variable "enable_resources" {
  description = "Guardia de seguridad para prevenir creación de recursos"
  type        = bool
  default     = false  # ← NO se crean recursos por defecto
}

# En cada módulo (IAM, S3, DynamoDB)
resource "aws_iam_role" "example" {
  count = var.enable_resources ? 1 : 0  # ← Solo crea si es true
  # ...
}
```

### Comportamiento

| `enable_resources` | `terraform plan` | `terraform apply` | Resultado |
|--------------------|------------------|-------------------|-----------|
| `false` (defecto) | Muestra 0 recursos | No crea nada | **Seguro para estudio** |
| `true` | Muestra 3-5 recursos | Crea recursos AWS reales | **Requiere cuenta AWS** |

---

## Variables de Configuración

| Variable | Tipo | Defecto | Descripción |
|----------|------|---------|-------------|
| `aws_region` | string | `us-east-1` | Región AWS (amigable con free tier) |
| `project_name` | string | `claimsops` | Nombre del proyecto para nombrar recursos |
| `environment` | string | `dev` | Ambiente: dev, staging, prod |
| `enable_versioning` | bool | `false` | Versionado S3 (agrega costo) |
| `dynamodb_billing_mode` | string | `PAY_PER_REQUEST` | Modo de facturación DynamoDB |
| **`enable_resources`** | **bool** | **`false`** | **Guardia crítica de seguridad** |

Para ejemplos detallados de configuración, ver [`terraform.tfvars.example`](infra/terraform/terraform.tfvars.example).

---

## Características de Seguridad

### IAM Privilegio Mínimo

El rol `claimsops-app-executor` tiene **permisos mínimos**:

✅ **Permitido**:
- S3: Crear/leer/escribir solo en buckets `claimsops-*`
- DynamoDB: Operaciones CRUD solo en tablas `claimsops-*`
- Lambda: Administrar funciones `claimsops-*` (opcional)
- CloudWatch: Crear logs para grupos `claimsops-*`

❌ **Denegado** (por omisión):
- RDS, ECS, EKS (servicios caros)
- Modificaciones IAM
- Creación de NAT Gateway
- Acceso entre cuentas

### Seguridad S3

- ✅ Encriptación AES256 en reposo (claves administradas por AWS)
- ✅ Acceso público bloqueado en 4 niveles
- ✅ Versionado deshabilitado por defecto (optimización de costos)
- ✅ Nombre de bucket incluye ID de cuenta (único en AWS)

### Seguridad DynamoDB

- ✅ Encriptación en reposo (automática)
- ✅ Encriptación en tránsito (HTTPS)
- ✅ Facturación PAY_PER_REQUEST (sin capacidad desperdiciada)
- ✅ Streams habilitados para procesamiento de eventos

---

## Estimación de Costos

### Free Tier (Primeros 12 Meses)

| Recurso | Límite Free Tier | Uso Esperado | Costo |
|---------|------------------|--------------|-------|
| S3 | 5 GB almacenamiento | < 1 GB | **$0/mes** |
| DynamoDB | 25 GB + 25 RCU/WCU | < 1 GB | **$0/mes** |
| Rol IAM | Ilimitado | 1 rol | **$0/mes** |
| **Total** | | | **$0/mes** |

### Más Allá del Free Tier

- S3: $0.023/GB-mes
- DynamoDB: $1.25/millón de escrituras
- Total (uso bajo): **$5-10/mes**

Para análisis detallado de costos, ver [`docs/costs.md`](docs/costs.md).

---

## Documentación

- 📖 [Arquitectura](docs/architecture.md) - Diseño del sistema y diagramas
- 📖 [Runbook](docs/runbook.md) - Guía paso-a-paso de despliegue
- 📖 [Costos](docs/costs.md) - Análisis detallado de costos y optimización
- 📖 [CONTRIBUTING](CONTRIBUTING.md) - Cómo contribuir
- 📖 [IMPROVEMENTS](docs/IMPROVEMENTS.md) - Roadmap Kaizen

---

## Operaciones Comunes

### Inicializar (Primera Vez)

```bash
cd infra/terraform
terraform init
```

### Validar Configuración

```bash
terraform fmt -check -recursive  # Verificar formato
terraform validate                # Validar sintaxis
```

### Planificar Cambios

```bash
# Simulación (muestra qué se crearía)
terraform plan

# Guardar plan en archivo
terraform plan -out=tfplan
```

### Aplicar Cambios

```bash
# Desplegar con confirmación
terraform apply

# Desplegar sin confirmación (¡cuidado!)
terraform apply -auto-approve
```

### Destruir Recursos

```bash
# Eliminar todos los recursos creados
terraform destroy

# Destruir recurso específico
terraform destroy -target=module.s3
```

### Ver Outputs

```bash
# Mostrar todos los outputs
terraform output

# Mostrar output específico
terraform output s3_bucket_name
```

---

## Resolución de Problemas

### "Error: No valid credential sources found"

**Causa**: Credenciales AWS no configuradas  
**Solución**: 
```bash
aws configure
# Ingresar: Access Key ID, Secret Access Key, Region
```

### "terraform: command not found"

**Causa**: Terraform no instalado  
**Solución**: [Descargar Terraform](https://www.terraform.io/downloads)

### "Error: Module not installed"

**Causa**: Módulos no inicializados  
**Solución**: 
```bash
terraform init
```

### "0 resources to add" pero quiero desplegar

**Causa**: `enable_resources = false` (guardia de seguridad activa)  
**Solución**: 
```hcl
# En terraform.tfvars
enable_resources = true
```

---

## Relación con ClaimOps-App

Este proyecto de infraestructura (`ClaimOps-Platform`) soporta el código de aplicación (`ClaimOps-App`):

| Platform (Infraestructura) | App (Aplicación) |
|----------------------------|------------------|
| Define **qué** recursos existen | Usa recursos para **procesar reclamos** |
| Rol IAM para control de acceso | Asume rol para acceder S3/DynamoDB |
| Bucket S3 para almacenar documentos | Sube documentos de reclamos |
| Tabla DynamoDB para log de auditoría | Escribe eventos de auditoría |

**Importante**: Estos son **repositorios Git separados**. No mezclar código de aplicación con código de infraestructura.

---

## Contribuir

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para:
- Flujo de trabajo Git
- Estrategia de branching
- Convenciones de commits
- Proceso de code review

---

## Licencia

Este proyecto es educativo y enfocado en estudio. Ver archivo LICENSE para detalles.

---

## Soporte

- 📧 Issues: [GitHub Issues](https://github.com/SvillarroelZ/ClaimOps-Platform/issues)
- 📖 Docs: Ver directorio `docs/`
- 💬 Preguntas: Abrir discusión en GitHub

---

**Construido con ❤️ para aprender Infraestructura como Código**

---

**[⬆ Volver arriba](#claimops-platform---infraestructura-como-código)**
