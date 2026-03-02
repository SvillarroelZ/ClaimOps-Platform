# 🚀 QUICKSTART - ClaimOps Platform Infrastructure

**En 5 minutos entiende de qué se trata este proyecto.**

---

## ¿QUÉ ES ESTO?

Un proyecto educativo de **infraestructura en AWS** escrito con **Terraform**.

✅ Aprenderás:
- Terraform (Infrastructure as Code)
- AWS (IAM, S3, DynamoDB)
- Seguridad en la nube
- Buenas prácticas DevOps

✅ Listo para:
- Llevar a AWS (cuando tengas cuenta)
- Extender con más servicios
- Usar como referencia

---

## COMIENZA AQUÍ

### Opción 1️⃣: Solo leer (sin AWS)

```bash
# 1. Clone el repo
git clone https://github.com/SvillarroelZ/ClaimOps-Platform.git
cd ClaimOps-Platform

# 2. Lee en este orden:
cat README.md                      # Overview (5 min)
cat docs/IMPROVEMENTS.md           # Qué se va a hacer (10 min)
cat AUDIT_REPORT.md               # Análisis completo (15 min)

# 3. Explora el código
ls infra/terraform/
cat infra/terraform/variables.tf   # Variables
cat infra/terraform/main.tf        # Cómo se orquesta
```

**Tiempo total**: 30 minutos

---

### Opción 2️⃣: Validar código (necesita Terraform)

```bash
# 1. Instala Terraform
# Descarga desde: https://www.terraform.io/downloads

# 2. Valida el código
cd infra/terraform
terraform init      # Descarga módulos
terraform validate  # Verifica sintaxis
terraform fmt -check -recursive  # Verifica formato

# 3. Ve el plan (no deploya nada)
terraform plan -out=plan.tfplan   # Qué se crearía
cat plan.tfplan | jq              # Ver en JSON
```

**Tiempo total**: 10 minutos  
**Costo**: $0 (solo validación)

---

### Opción 3️⃣: Desplegar (necesita AWS)

⚠️ **Requiere**: Tarjeta de crédito para AWS (no se cobrará si cabe en free tier)

```bash
# 1. Crea cuenta AWS (si no tienes)
# https://aws.amazon.com/free/

# 2. Configura credenciales
aws configure
# Ingresa:
#   AWS Access Key ID: [copia de AWS Console]
#   AWS Secret Access Key: [copia de AWS Console]
#   Default region: us-east-1
#   Default output format: json

# 3. Crea archivo de variables
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edita terraform.tfvars con tus valores

# 4. Despliega
terraform plan       # Ve qué se va a crear
terraform apply      # ✅ CREA RECURSOS EN AWS

# 5. Verifica
terraform output     # Ve qué se creó
aws s3 ls            # Ver buckets
aws dynamodb list-tables  # Ver tablas

# 6. Destruye (opcional, cuando termines)
terraform destroy    # Borra los recursos
```

**Tiempo total**: 20 minutos  
**Costo**: $0-5 (si todo cabe en free tier)

---

## ESTRUCTURA DEL PROYECTO

```
ClaimOps-Platform/
│
├── 📖 README.md                  ← START HERE
├── 📖 PROJECT_SUMMARY.md         ← Este documento
├── 📖 QUICKSTART.md              ← Guía rápida (ESTE)
├── 📖 CONTRIBUTING.md            ← Cómo aportar
├── 📖 AUDIT_REPORT.md            ← Análisis detallado
│
├── infra/terraform/              ← CÓDIGO IMPORTANTE
│   ├── providers.tf              # AWS config
│   ├── variables.tf              # Entrada
│   ├── outputs.tf                # Salida
│   ├── main.tf                   # Orquestación
│   ├── terraform.tfvars.example  # Template
│   │
│   └── modules/                  # Componentes
│       ├── iam/main.tf           # Rol de acceso
│       ├── s3/main.tf            # Almacenamiento
│       └── dynamodb/main.tf      # Base de datos
│
└── docs/                         # Documentación
    └── IMPROVEMENTS.md           # Plan de mejoras
```

---

## CONCEPTOS CLAVE

### 🔐 Seguridad (Least Privilege)

El proyecto da **solo los permisos necesarios**:

✅ Puede: Crear/borrar S3 y DynamoDB  
❌ NO puede: Modificar IAM, RDS, ECS, NAT

```hcl
# Esto es lo que se permite:
{
  "Effect": "Allow",
  "Action": [
    "s3:CreateBucket",
    "s3:DeleteBucket",
    "dynamodb:CreateTable"
  ],
  "Resource": [
    "arn:aws:s3:::claimsops-*",
    "arn:aws:dynamodb:*:*:table/claims*"
  ]
}
```

### 💰 Costos (Free Tier Friendly)

| Recurso | Límite Free | Nuestro Uso | Costo |
|---------|------------|-------------|-------|
| S3 | 5 GB | 1 GB | $0 |
| DynamoDB | 25 GB | <1 GB | $0 |
| Requests | Ilimitados | 1M/mes | $0 |
| **TOTAL** | **-** | **-** | **$0/mes** |

### 🏗️ Terraform (IaC)

Terraform es un **lenguaje para describir infraestructura**:

```hcl
# En lugar de hacer esto por console:
# AWS Console → S3 → Create Bucket → ...
#
# Haces esto:

resource "aws_s3_bucket" "exports" {
  bucket = "claimsops-exports-${data.aws_caller_identity.current.account_id}"
}

# Beneficios:
# ✓ Versionable en Git
# ✓ Reproducible siempre igual
# ✓ Auditable
# ✓ Escalable
```

---

## COMANDOS ÚTILES

### Para Estudiar

```bash
# Ver estructura del proyecto
tree infra/

# Ver archivos por tamaño
find . -type f -exec wc -l {} + | sort -n

# Ver historial de cambios
git log --oneline
git show <commit>

# Ver diferencias
git diff HEAD~1
```

### Para Trabajar con Terraform

```bash
# Validación
terraform fmt -recursive         # Formatea
terraform validate              # Valida

# Planeación
terraform plan -json > plan.json # Exporta

# Aplicación
terraform apply -auto-approve   # Sin confirmar (⚠️ cuidado)
terraform apply -parallelism=1  # Uno a uno

# Limpieza
terraform destroy -auto-approve # Borra todo
```

### Para Git

```bash
# Crear feature
git checkout -b feature/nombre

# Ver cambios
git status
git diff

# Commit
git commit -m "feat: descripción"

# Subir
git push origin feature/nombre

# Pull request (en GitHub)
# Open PR en GitHub.com
```

---

## TROUBLESHOOTING

### "Error: Falta Terraform"
**Solución**: Descarga desde https://www.terraform.io/downloads

### "terraform: command not found"
**Solución**: 
```bash
# En Mac
brew install terraform

# En Linux
sudo apt-get install terraform

# En Windows
choco install terraform
```

### "error: Cannot find child module"
**Solución**: 
```bash
cd infra/terraform
terraform init  # Descarga módulos
```

### "Error: Access Denied" (AWS)
**Causas**:
- ❌ Credenciales incorrectas → `aws configure` de nuevo
- ❌ Permisos insuficientes → Usa usuario con AdministratorAccess
- ❌ Región equivocada → Cambia en terraform.tfvars

### "Error: Resource already exists"
**Solución**: Ya lo desplegaste antes
```bash
# Opción 1: Destruir y recrear
terraform destroy
terraform apply

# Opción 2: Importar estado existente
terraform import aws_s3_bucket.exports claimsops-exports-123456789
```

---

## PRÓXIMOS PASOS

### Semana 1 ✅
- [x] Entender qué es Terraform
- [x] Leer documentación
- [x] Validar código

### Semana 2
- [ ] Crear cuenta AWS
- [ ] Desplegar infraestructura
- [ ] Experimentar

### Semana 3
- [ ] Añadir Lambda module
- [ ] Configurar CI/CD
- [ ] Documentar learnings

### Mes 2+
- [ ] Multi-environment (dev/staging/prod)
- [ ] Disaster recovery
- [ ] Integration tests

**Roadmap completo**: Ver `docs/IMPROVEMENTS.md`

---

## APRENDE MÁS

### Oficiales
- [Terraform Docs](https://www.terraform.io/docs)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

### Tutoriales
- [Terraform AWS Tutorial](https://learn.hashicorp.com/tutorials/terraform/aws-build)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [DynamoDB Design Patterns](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)

### Comunidades
- Reddit: r/Terraform, r/aws
- Discord: Hashicorp Community
- GitHub: Terraform Registry

---

## ¿PREGUNTAS?

### "¿Necesito AWS para aprender?"
No. Puedes estudiar el código sin AWS. Pero es 10x mejor con AWS.

### "¿Cuánto cuesta?"
$0/mes si cabe en free tier (~5 GB S3 + <1 GB DynamoDB).

### "¿Puedo usar esto en producción?"
Parcialmente. Le falta:
- [ ] Multi-region replication
- [ ] Automated backups
- [ ] Disaster recovery
- [ ] Monitoring/alerting

Pero es perfecto para **MVP o staging**.

### "¿Cómo contribuyo?"
Lee `CONTRIBUTING.md` y abre un Pull Request.

---

## RESUMEN

**En 5 minutos**:
✅ Clonaste el repo  
✅ Entendiste la estructura  
✅ Viste ejemplos de código  

**En 30 minutos**:
✅ Leíste toda la documentación  
✅ Validaste con `terraform validate`  
✅ Entendiste conceptos AWS  

**En 2 horas**:
✅ Desplegaste en AWS  
✅ Viste recursos reales  
✅ Aprendiste Terraform  

---

## STATUS FINAL

```
🟢 Código:        ✅ Completo y validado
🟢 Documentación: ✅ Exhaustiva
🟢 Seguridad:     ✅ Implementada (least privilege)
🟢 Costos:        ✅ Optimizado (free tier)
🟢 Git:           ✅ Profesional (conventional commits)

🚀 LISTO PARA EMPEZAR
```

---

**Next Step**: Abre [README.md](README.md) para profundizar.

¡Que disfrutes aprendiendo infraestructura! 🎉
