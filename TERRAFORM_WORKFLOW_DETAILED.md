# TERRAFORM WORKFLOW - PASO A PASO

**Objetivo**: Entender exactamente qué ocurre en cada comando de Terraform.

---

## 🔄 FLUJO COMPLETO (5 pasos)

### PASO 1: terraform init
```
QUÉ HACE:
• Lee providers.tf → ve que necesita AWS provider ~5.0
• Descarga AWS provider de Terraform Registry
• Crea .terraform/providers/ (guardar versión exacta)
• Inicializa backend local (crea .terraform/ carpeta)
• Lee módulos en modules/iam, modules/s3, modules/dynamodb

RESULTADO:
✓ .terraform/ directory creado
✓ .terraform.lock.hcl creado (lock de versiones)
✓ Terraform está listo para validar

COMANDO:
$ cd infra/terraform
$ terraform init

SALIDA ESPERRADA:
Terraform initialized. Working directory contains terraform configuration files...
```

---

### PASO 2: terraform validate
```
QUÉ HACE:
• Lee todos los .tf files
• Verifica sintaxis (¿están bien los { } ?)
• Verifica references (¿existen las variables que menciono?)
• Verifica module sources (¿existen las carpetas modules/iam, etc?)
• NO toca AWS (no valida si IAM roles existen)

RESULTADO:
✓ Sintaxis correcta
✓ Referencias válidas
✓ Módulos encontrados

COMANDO:
$ terraform validate

SALIDA ESPERADA:
Success! The configuration is valid.

SALIDA EN CASO DE ERROR (ejemplo):
Error: Missing required argument
  on main.tf line 5, in module "s3":
    6: module "s3" {
The argument "aws_region" is required, but was not set.
```

---

### PASO 3: terraform plan
```
QUÉ HACE (CON enable_resources = false / DEFAULT):
• Lee variables.tf → ve enable_resources default = false
• Calcula: "Si enable_resources es false, entonces count = 0"
• Resultado final: 0 recursos a crear/eliminar/actualizar
• NO conecta a AWS (es análisis local)

QUÉ HACE (CON enable_resources = true):
• Lee variables.tf → ve enable_resources = true
• Calcula: "Si enable_resources es true, entonces count = 1"
• Se conecta a AWS (valida que provider está configurado)
• Compara: "¿Existen estos recursos en AWS ahora?"
• Resultado: "Aquí está el plan de cambios"

RESULTADO:
Con default (enable_resources=false):
Plan: 0 to add, 0 to change, 0 to destroy
↑ SEGURO - Nada sucede

Con enable_resources=true:
Plan: 3 to add, 0 to change, 0 to destroy
• 1 aws_dynamodb_table (claimsops-audit-events)
• 1 aws_iam_role (claimsops-deployment-role)
• 1 aws_s3_bucket (claimsops-exports-123456789)
↑ CUIDADO - Revisa bien antes de apply

COMANDO (opción 1 - seguro por defecto):
$ terraform plan

COMANDO (opción 2 - con guard explícito):
$ terraform plan -var="enable_resources=true"

COMANDO (opción 3 - guardar a archivo):
$ terraform plan -out=tfplan -var="enable_resources=true"
$ # Luego puedes revisar:
$ terraform show tfplan
```

---

### PASO 4: terraform apply
```
QUÉ HACE (CON enable_resources = false / DEFAULT):
1. Ejecuta terraform plan internamente
2. Ve "0 cambios"
3. No hace nada
4. Mensaje: "Apply complete! Resources: 0 added, 0 changed, 0 destroyed"
↑ SEGURO

QUÉ HACE (CON enable_resources = true):
1. Ejecuta terraform plan internamente
2. Ve "3 cambios":
   - Crea aws_iam_role
   - Crea aws_s3_bucket
   - Crea aws_dynamodb_table
3. Antes de crear, PIDE TU CONFIRMACIÓN:
   "Do you want to perform these actions?"
4. Espera "yes" de tu parte
5. Si escribes "yes":
   - Valida que tienes AWS credentials
   - Conecta a AWS (region us-east-1 por default)
   - Crea los 3 recursos
   - Escribe terraform.tfstate (registro del estado)
6. Si escribes "no" o ^C:
   - Cancela
   - No crea nada

RESULTADO si dices "yes":
Apply complete! Resources: 3 added, 0 changed, 0 destroyed

terraform.tfstate ahora contiene:
{
  "resources": [
    {
      "type": "aws_iam_role",
      "name": "deployment_role",
      "instances": [{
        "attributes": {
          "arn": "arn:aws:iam::123456789:role/claimsops-deployment-role",
          "name": "claimsops-deployment-role"
        }
      }]
    },
    ... (s3 bucket, dynamodb table)
  ]
}

COMANDO (opción 1 - automático):
$ terraform apply -var="enable_resources=true"
# Te pide "Do you want to perform these actions?" (yes/no)

COMANDO (opción 2 - con pre-aprobación):
$ terraform apply -var="enable_resources=true" -auto-approve
# ⚠ DANGER - No pide confirmación

COMANDO (opción 3 - aplicar un plan guardado):
$ terraform apply tfplan
# Aplica exactamente lo que plan decía (más seguro)
```

---

### PASO 5: terraform destroy
```
QUÉ HACE:
• Lee terraform.tfstate
• Ve qué recursos existen en AWS
• Calcula: "Debo borrar estos 3 recursos"
• Antes de borrar, PIDE TU CONFIRMACIÓN
• Si dices "yes":
  - Borra aws_dynamodb_table
  - Borra aws_s3_bucket (con su contenido)
  - Borra aws_iam_role
  - Actualiza terraform.tfstate (marca como borrado)
• Si dices "no":
  - Cancela

RESULTADO si dices "yes":
Destroy complete! Resources: 3 destroyed.

terraform.tfstate ahora está "limpio" (vacío de recursos)

COMANDO:
$ terraform destroy
# Te pide "Do you really want to destroy all resources?" (yes/no)

COMANDO con auto-approve (CUIDADO):
$ terraform destroy -auto-approve
# ⚠ No pide confirmación - borra todo sin aviso
```

---

## 📊 MATRIZ DE DECISIONES

### Escenario 1: Estoy estudiando (HAZE AHORA)
```
$ terraform init           ← Preparar
$ terraform plan           ← Ver qué haría (con guard = 0 cambios)
$ terraform validate       ← Verificar sintaxis
```
**Resultado**: ✓ Código validado, 0 cambios aplicados, seguro 100%

---

### Escenario 2: Quiero ver QUÉ crearía
```
$ terraform init                                   ← Preparar
$ terraform plan -var="enable_resources=true"     ← Ver el plan
$ terraform show -json tfplan | jq '..' > plan.json  ← Guardar para reporte
```
**Resultado**: ✓ Plan guardado, puedes revisarlo, 0 recursos creados

---

### Escenario 3: Quiero crear la infraestructura (CUIDADO - $$$)
```
$ terraform plan -out=tfplan -var="enable_resources=true"  ← Generar plan
$ # Revisa tfplan en detail, muéstralo a colegas
$ terraform apply tfplan  ← Aplica el plan generado
```
**Resultado**: ✓ 3 recursos creados en AWS, costo ~$0.50-$1 el primer día

---

### Escenario 4: Cometí un error, quiero cleanup
```
$ terraform destroy   ← Borra todo
# Responde "yes" cuando pida confirmación
```
**Resultado**: ✓ 3 recursos borrados de AWS, costo vuelve a $0

---

## 🛡️ SAFETY GUARD EN ACCIÓN

### Cómo el guard previene desastres

```
INTENCIÓN: Alguien accidentalmente hace terraform apply

PASO 1: Ejecuta comando
$ cd infra/terraform
$ terraform apply

PASO 2: Terraform lee variables.tf
variable "enable_resources" {
  default = false   ← Aquí está el guard
}

PASO 3: Terraform calcula
if enable_resources == true
  count = 1  (crear recurso)
else
  count = 0  (NO crear resurso)

→ enable_resources es false → count = 0

PASO 4: Plan que terraform genera
Plan: 0 to add, 0 to change, 0 to destroy
↑ NADA PASA - El guard lo protegió

PASO 5: Terraform pide confirmación
Do you want to perform these actions?
↑ Incluso con 0 cambios, lo pregunta

RESULTADO: 
Zero impacto, zero costo, zero riesgo
```

---

## 🔐 FLUJO CON SEGURIDAD (RECOMENDADO)

```
DEV: Escribe código 
    ↓
CODE REVIEW: Compañero revisa en GitHub
    ↓
CI/CD PIPELINE: GitHub Actions corre:
    • terraform init
    • terraform validate
    • terraform plan (genera plan.json)
    • terraform fmt --check
    ↓
PLAN APROBADO: Si todo está bien
    ↓
PRODUCTION: Alguien con permisos AWS hace:
    • terraform apply -var="enable_resources=true"
    • Valida credenciales
    • Crea recursos
    ↓
TERRAFORM.TFSTATE: Guardado seguro en S3 (fase 2)
```

---

## 📁 QUÉ ARCHIVOS CREA/MODIFICA TERRAFORM

### Archivos que TÚ escribes:
```
infra/terraform/
├── providers.tf       ← AWS provider version
├── variables.tf       ← Inputs (aws_region, enable_resources, etc)
├── main.tf            ← Modulos (iam, s3, dynamodb)
├── outputs.tf         ← Valores que exporta
├── terraform.tfvars   ← Valores específicos (NUNCA committear a Git)
└── modules/
    ├── iam/main.tf
    ├── s3/main.tf
    └── dynamodb/main.tf
```

### Archivos que TERRAFORM crea/modifica:
```
infra/terraform/
├── .terraform/                      ← Providers descargados (ignored by .gitignore)
├── .terraform.lock.hcl              ← Lock de versiones (COMMIT ESTO)
├── terraform.tfstate                ← Record del estado (ignored by .gitignore)
├── terraform.tfstate.backup         ← Backup anterior (ignored by .gitignore)
└── tfplan                           ← Plan guardado (opcional, ignored)
```

### Cuál commitear a Git:
```
✓ COMMIT ESTO:
  infra/terraform/         (todo código .tf)
  infra/terraform/.gitignore (cuáles ignorar)
  .terraform.lock.hcl      (lock de versiones = reproducible)

✗ NO commitear ESTO:
  terraform.tfstate        (contiene secrets, IDs privados)
  .terraform/              (demasiado grande, se regenera con init)
  terraform.tfvars         (valores específicos del dev)
  *.tfplan                 (genera localmente cada vez)
```

---

## 🎯 REGLAS DE ORO

### Regla 1: Siempre terraform plan antes de apply
```bash
# NO hagas nunca:
terraform apply -auto-approve   ← ⚠ Peligro

# Haz siempre:
terraform plan -out=tfplan
# Revisa tfplan
terraform apply tfplan          ← ✓ Seguro
```

### Regla 2: terraform.tfstate es sagrado
```
Es la FUENTE DE VERDAD de qué existe en AWS.
Si se pierde → Desastre
Si se corrompe → Desastre

Por eso:
✓ .gitignore lo protege (no va a Git)
✓ En producción va a backend remoto (S3 + lock)
✓ Siempre hacer backup antes de destroy
```

### Regla 3: enable_resources es tu salvavidas
```hcl
variable "enable_resources" {
  default = false   ← Siempre false por defecto
}
```
Si alguien hace `terraform apply` sin saber qué hace → Nada pasa.

### Regla 4: terraform plan es gratis
```
• No cuesta dinero
• No toca AWS resources
• Corre local
• Usa frecuentemente para validar
```

---

## ❓ QUÉ PASA SI...

### Q: ¿Qué pasa si terraform init falla?
A: 
```
Probable causa: No tienes Terraform instalado (versión >= 1.0)
Fix: Install Terraform https://www.terraform.io/downloads
```

### Q: ¿Qué pasa si terraform validate falla?
A:
```
Probable causa: Sintaxis error en los .tf files
Fix: Lee el mensaje de error, busca la línea indicada, corrígela
```

### Q: ¿Qué pasa si terraform plan falla?
A:
```
Probable causa 1: No tienes AWS credentials configuradas
Fix: aws configure (y poner ACCESS KEY / SECRET)

Probable causa 2: enable_resources = true pero región no existe
Fix: Verifica aws_region válida (us-east-1, eu-west-1, etc)
```

### Q: ¿Qué pasa si terraform apply crea recursos pero no los necesito?
A:
```
No problem:
$ terraform destroy    ← Los borra todos
Responde: yes
FIN - Costo vuelve a $0
```

### Q: ¿Qué pasa si terraform.tfstate se corrompe?
A:
```
No ideal pero recuperable:
1. terraform state list    ← Ver qué piensa que existe
2. terraform state show module.s3.aws_s3_bucket.exports  ← Ver detalles
3. Si en AWS el recurso sigue existiendo:
   terraform import module.s3.aws_s3_bucket.exports claimsops-exports-XXX
4. terraform plan        ← Verifica que sincroniza
5. FIN - Estado recuperado
```

---

## 📚 COMANDOS ÚTILES

| Comando | Qué hace | Costo |
|---------|----------|-------|
| `terraform validate` | Verifica sintaxis | $0 |
| `terraform fmt` | Formatea código | $0 |
| `terraform plan` | Dry run (sin enable_resources) | $0 |
| `terraform plan -var="enable_resources=true"` | Dry run (con recursos) | $0 |
| `terraform apply` | Crea recursos si enable_resources=true | $$$ |
| `terraform destroy` | Borra todo | $0 (después de borrar) |
| `terraform show` | Muestra estado actual | $0 |
| `terraform state list` | Lista recursos | $0 |
| `terraform state show` | Detalles de 1 recurso | $0 |
| `terraform refresh` | Sincroniza estado con AWS | $0 |
| `terraform import` | Añade recurso existente al state | $0 |

---

## 🎬 PRÓXIMOS PASOS (DESPUÉS DE PRESENTACIÓN)

**Fase 2 - Backend Remoto** (2-3 días):
```
Migrar terraform.tfstate de local a S3:

ACTUAL (hoy):
backend "local" {
  path = "terraform.tfstate"    ← Archivo local
}

FUTURO (fase 2):
backend "s3" {
  bucket         = "claimsops-terraform-state"  ← Remoto en S3
  key            = "prod/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-lock"             ← Lock distribuido
  encrypt        = true                         ← Encrypted at rest
}

BENEFICIO:
✓ State compartido entre teammates
✓ DynamoDB lock evita conflictos (dos personas apply a la vez)
✓ Encrypted en S3 (secrets protegidos)
✓ Versioning (puedes ver histórico)
```

**Fase 3 - CI/CD Pipeline** (3-4 días):
```
GitHub Actions que valida PRs automáticamente:

ON PUSH TO MAIN:
  1. terraform init
  2. terraform validate
  3. terraform plan
  4. (Human approval)
  5. terraform apply (si PR approved)

RESULT:
✓ Nadie hace deploy sin validación
✓ Nadie puede olvidarse de terraform plan
✓ Auditoría de quién deployó qué y cuándo
```

**Fase 4 - KMS Keys** (1-2 días):
```
Cambiar de AES256 (AWS-managed) a KMS (customer-managed):

ACTUAL:
server_side_encryption_configuration {
  encryption_key = "aws/s3"  ← AWS key
}

FUTURO:
server_side_encryption_configuration {
  encryption_key = "arn:aws:kms:..."  ← Tu key
}

BENEFICIO:
✓ Control granular de rotación
✓ Auditoría de acceso a keys (CloudTrail)
✓ Satisface compliance (PCI, HIPAA, etc)
```

---

**Última actualización**: March 2, 2026  
**Próxima revisión**: Después de presentación  
**Documentación**: Completa y actualizada
