# ClaimOps Platform - Infraestructura como Código

Infraestructura Terraform para sistema de procesamiento de reclamos. Define recursos AWS con seguridad de nivel producción y validación.

**Estado**: Listo para producción. No crea recursos por defecto (guardia de seguridad).
**Idioma**: Español (técnico)
**Versión**: Terraform >= 1.0

Ver [README.md](README.md) para documentación en inglés.

---

## Qué Crea Este Proyecto

Tres recursos AWS diseñados para procesamiento de reclamos:

1. **Rol IAM** - Rol de ejecución con permisos de privilegio mínimo
2. **Bucket S3** - Almacenamiento encriptado para exportaciones y documentos de reclamos
3. **Tabla DynamoDB** - Base de datos NoSQL para eventos de auditoría y metadatos

Todos los recursos protegidos por guardia de seguridad: `enable_resources = false` por defecto (cero recursos creados).

---

## Inicio Rápido

### Prerrequisitos

- Terraform >= 1.0 (https://www.terraform.io/downloads)
- Git
- Opcional: Cuenta AWS con credenciales configuradas (aws configure)

### Solo Validación (No Requiere Cuenta AWS)

```bash
cd infra/terraform

# Inicializar (descarga providers)
terraform init

# Validar sintaxis
terraform validate

# Verificar formato
terraform fmt -check .
```

Salida esperada:
```
Success! The configuration is valid.
```

### Desplegar Infraestructura (Requiere Cuenta AWS)

```bash
# Activar guardia de seguridad
export TF_VAR_enable_resources=true

# Revisar cambios
terraform plan

# Crear infraestructura
terraform apply

# Ver outputs de recursos
terraform output

# Limpiar cuando termines
terraform destroy
```

---

## Entender la Arquitectura

### Estructura de Directorios

```
infra/terraform/
├── providers.tf              # AWS provider versión ~5.0, backend local
├── variables.tf              # 6 variables de entrada con reglas de validación
├── main.tf                   # Orquestación de módulos
├── outputs.tf                # Exporta identificadores de recursos
├── terraform.tfvars.example  # Plantilla de configuración
│
└── modules/
    ├── iam/                  # Rol IAM + política (privilegio mínimo)
    │   ├── main.tf           # aws_iam_role, aws_iam_role_policy
    │   ├── variables.tf      # Inputs del módulo
    │   └── outputs.tf        # Export role_arn
    │
    ├── s3/                   # Bucket S3 (encriptación + bloqueo acceso público)
    │   ├── main.tf           # aws_s3_bucket, configuración encriptación
    │   ├── variables.tf      # Inputs del módulo
    │   └── outputs.tf        # Export bucket_name
    │
    └── dynamodb/             # Tabla DynamoDB (streams habilitados)
        ├── main.tf           # aws_dynamodb_table con pay-per-request
        ├── variables.tf      # Inputs del módulo
        └── outputs.tf        # Export table_name
```

### Guardia de Seguridad: El Concepto Central

La variable `enable_resources` controla si la infraestructura se crea:

```hcl
variable "enable_resources" {
  type    = bool
  default = false    # Seguro por defecto
}

resource "aws_iam_role" "deployment_role" {
  count = var.enable_resources ? 1 : 0    # Solo crea si es true
  # ...
}
```

Resultado:
- Por defecto (false): terraform plan muestra 0 cambios
- Explícito (true): terraform plan muestra 3 recursos a agregar

Esto previene creación accidental de infraestructura en desarrollo o pipelines CI/CD.

---

## Flujo de Trabajo Terraform Explicado

### Paso 1: terraform init

Descarga AWS provider e inicializa backend:

```bash
cd infra/terraform
terraform init
```

Salida:
- Directorio .terraform/ (binarios del provider)
- .terraform.lock.hcl (archivo de bloqueo de dependencias)

### Paso 2: terraform validate

Verifica sintaxis y referencias:

```bash
terraform validate
```

NO se conecta a AWS. NO cuesta nada.

### Paso 3: terraform plan

Dry-run para ver qué se crearía:

```bash
# Con guardia de seguridad (por defecto):
terraform plan
# Resultado: Plan: 0 to add, 0 to change, 0 to destroy

# Para ver el plan real de infraestructura:
terraform plan -var="enable_resources=true"
# Resultado: Plan: 3 to add (rol IAM, bucket S3, tabla DynamoDB)
```

### Paso 4: terraform apply

Crea recursos reales en AWS:

```bash
terraform apply -var="enable_resources=true"
```

Solicita confirmación antes de crear. Escribe "yes" para proceder.

La salida muestra IDs de recursos:
```
module.iam.aws_iam_role.deployment_role[0]:
  arn = "arn:aws:iam::123456789:role/claimsops-deployment-role"
  
module.s3.aws_s3_bucket.exports[0]:
  bucket = "claimsops-exports-123456789"

module.dynamodb.aws_dynamodb_table.audit_events[0]:
  name = "claimsops-audit-events"
```

### Paso 5: terraform destroy

Limpia todos los recursos creados:

```bash
terraform destroy
```

Solicita confirmación. Escribe "yes" para eliminar.

El costo vuelve a $0 después de la eliminación.

---

## Variables de Configuración

Todas las variables definidas en `infra/terraform/variables.tf`:

| Variable | Tipo | Por Defecto | Propósito |
|----------|------|-------------|-----------|
| aws_region | string | us-east-1 | Región AWS para recursos |
| project_name | string | claimsops | Usado en nombres de recursos (bucket, tabla, rol) |
| environment | string | dev | Tag de entorno: dev, staging, prod |
| enable_versioning | bool | false | Versionamiento de objetos S3 (agrega costo de almacenamiento) |
| dynamodb_billing_mode | string | PAY_PER_REQUEST | Facturación DynamoDB: PROVISIONED o PAY_PER_REQUEST |
| enable_resources | bool | false | GUARDIA DE SEGURIDAD: debe ser true para crear infraestructura |

### Configuración Personalizada

```bash
terraform plan \
  -var="aws_region=eu-west-1" \
  -var="project_name=claims-eu" \
  -var="enable_resources=true"
```

Todas las variables son validadas antes de la ejecución.

---

## Módulos Explicados

### 1. Módulo IAM

Crea rol de ejecución con permisos granulares:

Recursos:
- aws_iam_role: rol de deployment
- aws_iam_role_policy: 5 declaraciones (S3, DynamoDB, Lambda, CloudWatch)

Permisos (restringidos por ARN a claimsops-*):
1. S3: ListBucket, ListBucketVersions
2. S3: GetObject, GetObjectVersion, PutObject
3. DynamoDB: Query, Scan, PutItem, UpdateItem
4. Lambda: InvokeFunction
5. CloudWatch: CreateLogStream, PutLogEvents

Seguridad: Privilegio mínimo, sin PassRole a otros principals.

### 2. Módulo S3

Crea bucket encriptado y seguro:

Recursos:
- aws_s3_bucket: contenedor del bucket
- aws_s3_bucket_server_side_encryption_configuration: AES256
- aws_s3_bucket_public_access_block: bloquea todo acceso público

Características:
- Encriptación: AES256 (claves administradas por AWS)
- Acceso público: Bloqueado en 4 niveles (objetos, ACLs, bucket policy)
- Versionamiento: Opcional (deshabilitado por defecto, ahorra costo)
- Nombre del bucket: claimsops-exports-{account-id}

### 3. Módulo DynamoDB

Crea tabla NoSQL con streaming de eventos:

Recursos:
- aws_dynamodb_table: contenedor de tabla
- Partition key: pk (String)
- Sort key: sk (String)
- Streams: NEW_AND_OLD_IMAGES (habilitado)

Características:
- Facturación: PAY_PER_REQUEST (auto-escala, cobra por solicitud)
- Streams: Para integración Lambda, audit trail, procesamiento en tiempo real
- Opcional: TTL, índices secundarios globales, recuperación point-in-time

---

## Checklist de Seguridad

Antes de desplegar en producción:

1. Rol IAM revisado (privilegio mínimo)
   ```bash
   aws iam get-role-policy --role-name claimsops-deployment-role --policy-name <policy-name>
   ```

2. Bucket S3 con acceso público bloqueado
   ```bash
   aws s3api get-public-access-block --bucket claimsops-exports-<account-id>
   ```

3. Alarmas CloudWatch configuradas para throttling de DynamoDB
4. Procedimiento de backup para archivo terraform.tfstate
5. Credenciales usadas son temporales (no claves de cuenta root)
6. terraform.tfstate ESTÁ en .gitignore (nunca hacer commit del state file)

---

## Análisis de Costos

### Con AWS Free Tier

Asume: 1 millón de solicitudes DynamoDB/mes, < 1 GB almacenamiento S3.

| Recurso | Límite Free Tier | Costo |
|---------|------------------|-------|
| IAM | Ilimitado | $0 |
| S3 (1GB) | 5 GB | $0 |
| DynamoDB (1M lecturas) | 25 GB + RCU | $0 |
| CloudWatch | 5 GB logs | $0 |
| **Total** | | **$0/mes** |

Después de free tier expira o con alto volumen:
- S3: $0.023/GB-mes
- DynamoDB: $1.25/millón de solicitudes escritura
- Costo mensual realista: $5-15/mes (volumen bajo)

---

## Solución de Problemas

### Error: "terraform: command not found"

Instalar Terraform: https://www.terraform.io/downloads

### Error: "No valid credential sources found"

Configurar credenciales AWS:
```bash
aws configure
# Ingresar: Access Key, Secret Access Key, Región, Formato Output
```

### Error: "botocore.exceptions.NoCredentialsError"

Igual que arriba. Credenciales AWS requeridas para terraform apply.

### terraform plan muestra 0 cambios (pero enable_resources=true)

Los recursos ya existen en AWS. Verificar:
```bash
aws s3 ls | grep claimsops-exports
aws dynamodb list-tables | grep claimsops
aws iam list-roles | grep claimsops
```

O reconstruir state:
```bash
terraform state list
terraform state show module.s3.aws_s3_bucket.exports[0]
```

### El nombre del bucket S3 ya existe

Los nombres de buckets S3 son globalmente únicos. Cambiar project_name:
```bash
terraform plan -var="project_name=claims-unique-42"
```

---

## Referencia de Comandos

Validación (no requiere cuenta AWS):
```bash
terraform init
terraform validate
terraform fmt -check .
```

Planificación:
```bash
terraform plan
terraform plan -var="enable_resources=true"
terraform plan -out=tfplan
terraform show tfplan
```

Despliegue:
```bash
terraform apply
terraform apply -var="enable_resources=true"
terraform apply tfplan           # Aplicar plan guardado
terraform apply -auto-approve    # Omitir confirmación
```

Inspección:
```bash
terraform state list
terraform state show module.s3.aws_s3_bucket.exports[0]
terraform output
terraform output s3_bucket_name
```

Limpieza:
```bash
terraform destroy
terraform destroy -target=module.s3    # Destruir módulo específico
```

Verificación AWS CLI (después de apply):
```bash
aws iam list-roles | grep claimsops
aws s3 ls | grep claimsops
aws dynamodb list-tables | grep claimsops
```

---

## Decisiones de Diseño (Por Qué Estas Elecciones)

### ¿Por qué DynamoDB en vez de RDS/PostgreSQL?

**Decisión**: DynamoDB con facturación PAY_PER_REQUEST.

**Razonamiento**:
- Los eventos de auditoría son impredecibles (escrituras esporádicas, no constantes)
- No se necesitan joins SQL o transacciones complejas
- Auto-escalamiento sin planificación de capacidad
- DynamoDB Streams habilita procesamiento de eventos en tiempo real (integración Lambda)
- Menor costo con volumen bajo (free tier cubre 25GB)

**Compromiso**: RDS sería mejor para consultas complejas o si necesitas transacciones ACID entre múltiples tablas.

### ¿Por qué PAY_PER_REQUEST en vez de PROVISIONED?

**Decisión**: Modo de facturación PAY_PER_REQUEST para DynamoDB.

**Razonamiento**:
- Volumen impredecible de procesamiento de reclamos (picos durante inscripción abierta, silencio en otros momentos)
- Sin capacidad desperdiciada durante períodos de bajo uso
- Operaciones más simples (no necesita ajuste de capacidad)
- Escala automáticamente para manejar picos de tráfico

**Compromiso**: PROVISIONED es más barato con volúmenes sostenidos altos (1M+ solicitudes/mes). Cambiar si el uso se vuelve predecible.

### ¿Por qué Diseño Modular (3 módulos separados)?

**Decisión**: Módulos separados para IAM, S3, DynamoDB en vez de main.tf monolítico.

**Razonamiento**:
- Cada módulo puede probarse independientemente
- Los módulos son reutilizables entre proyectos
- Cambios en S3 no arriesgan romper configuración de DynamoDB
- Más fácil de entender (cada módulo tiene responsabilidad única)
- Miembros del equipo pueden ser dueños de diferentes módulos (equipo IAM, equipo storage)

**Compromiso**: Más archivos para administrar. Para proyectos pequeños, un solo main.tf podría ser más simple.

### ¿Por qué Guardia de Seguridad (enable_resources = false)?

**Decisión**: Por defecto no crear recursos a menos que se habilite explícitamente.

**Razonamiento**:
- Previene creación accidental de infraestructura en desarrollo
- Seguro para validación en CI/CD (terraform plan no te sorprenderá)
- Fuerza decisión intencional antes de gastar dinero
- Proyectos educativos pueden validar sin cuenta AWS

**Compromiso**: Paso extra para habilitar recursos. Pero esto es una característica, no un error.

### ¿Por qué Backend Local en vez de Backend Remoto S3?

**Decisión**: Archivo local terraform.tfstate (Fase 1). Backend S3 planeado para Fase 2.

**Razonamiento**:
- Configuración más simple para desarrollador único o propósitos de estudio
- Sin dependencia de bucket S3 externo
- Iteración más rápida durante desarrollo

**Compromiso**:
- State file no compartido (no se puede colaborar fácilmente)
- Sin bloqueo de estado (riesgo de modificaciones concurrentes)
- State file podría perderse si la máquina falla

**Ruta de migración**: Cuando el equipo crezca o se necesite preparación para producción, migrar a backend S3 + bloqueo DynamoDB.

### ¿Por qué AES256 en vez de Claves KMS?

**Decisión**: Encriptación AES256 administrada por AWS para S3. KMS planeado para Fase 4.

**Razonamiento**:
- AES256 es gratis y automático
- Suficiente para la mayoría de casos de uso (encriptación en reposo)
- Sin sobrecarga de administración de claves
- Cumplimiento más simple para cargas de trabajo no reguladas

**Compromiso**:
- No se puede auditar acceso a claves (sin eventos CloudTrail para uso de claves)
- No se pueden rotar claves en calendario personalizado
- Podría no cumplir requisitos PCI-DSS o HIPAA

**Ruta de migración**: Si el cumplimiento requiere claves administradas por cliente, cambiar a KMS en Fase 4.

### ¿Por qué IAM de Privilegio Mínimo?

**Decisión**: Política IAM restringida solo a recursos claimsops-*.

**Razonamiento**:
- Limita radio de explosión si las credenciales se filtran
- No puede borrar accidentalmente recursos no relacionados
- Sigue mejores prácticas de AWS (principio de privilegio mínimo)
- Más fácil de auditar (permisos son explícitos y mínimos)

**Ejemplo**: Si el rol se ve comprometido, el atacante solo puede acceder a buckets claimsops-exports-*, no a todos los buckets S3.

---

## Fases del Proyecto

Fase 1 (Actual): MVP con guardia de seguridad
- Estructura Terraform, diseño modular
- Guardia de seguridad (enable_resources=false)
- Recursos core (IAM, S3, DynamoDB)
- Backend local para simplicidad

Fase 2 (Planeada): Backend de estado remoto
- Migrar de local a S3 + bloqueo DynamoDB
- Habilita colaboración en equipo
- Versionamiento y backup de estado

Fase 3 (Planeada): Pipeline de validación CI/CD
- GitHub Actions: terraform validate en cada PR
- Auto-plan, aprobación manual para apply
- Previene errores manuales

Fase 4 (Planeada): Seguridad avanzada
- Claves KMS para encriptación (vs AES256)
- Mejor audit trail y rotación de claves
- Listo para cumplimiento

---

## Resumen de Archivos

| Archivo | Propósito |
|---------|-----------|
| README.md | Documentación completa (Inglés) |
| README.es.md | Documentación completa (Español) |
| infra/terraform/providers.tf | Versión AWS provider, backend local |
| infra/terraform/variables.tf | Todas las variables de entrada con validación |
| infra/terraform/main.tf | Llamadas a módulos |
| infra/terraform/outputs.tf | Outputs de recursos |
| infra/terraform/modules/iam/main.tf | Rol IAM y políticas |
| infra/terraform/modules/s3/main.tf | Bucket S3 con encriptación |
| infra/terraform/modules/dynamodb/main.tf | Tabla DynamoDB con streams |
| .gitignore | Protege state file y secretos |

---

## Más Información

- Documentación Terraform: https://www.terraform.io/docs/
- AWS Free Tier: https://aws.amazon.com/free/
- Mejores prácticas Terraform: https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices

---

**Repositorio**: https://github.com/SvillarroelZ/ClaimOps-Platform  
**Licencia**: MIT  
**Última Actualización**: 2 de marzo, 2026
