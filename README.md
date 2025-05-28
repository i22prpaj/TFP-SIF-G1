# 🚀 Odoo 16 Deployment Scripts

<div align="center">

[![Odoo](https://img.shields.io/badge/Odoo-16.0-714B67?style=for-the-badge&logo=odoo&logoColor=white)](https://www.odoo.com/)
[![Docker](https://img.shields.io/badge/Docker-Latest-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-13-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![GCP](https://img.shields.io/badge/Google_Cloud-Ready-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com/)

**🚀 Automatiza el despliegue completo de Odoo 16 con PostgreSQL y Asterisk PBX**

*Despliega en minutos tu ERP completo con sistema VoIP integrado*

</div>

## 📋 Descripción

Este repositorio contiene scripts automatizados para desplegar **Odoo 16** con **PostgreSQL** y **Asterisk PBX** usando Docker Compose. Incluye dos versiones optimizadas para diferentes entornos:

- 🏠 **Local**: Para desarrollo y pruebas en tu máquina local
- ☁️ **Google Cloud Platform (GCP)**: Para producción en la nube

## ✨ Características

- ⚡ **Instalación automática** de Docker y Docker Compose
- 🐘 **PostgreSQL 13** preconfigurado como base de datos
- 📞 **Asterisk PBX** integrado para comunicaciones VoIP
- 🔧 **Configuración automática** del firewall (GCP)
- 💾 **Sistema de backups** incluido
- 🔄 **Gestión completa** del ciclo de vida de contenedores
- 📁 **Volúmenes persistentes** para datos y add-ons

## 🛠️ Instalación y Uso

### Paso 1: Descargar y guardar los scripts

1. **Guarda** los archivos en tu sistema:
   - `odoo16-local.sh` (para entorno local)
   - `odoo16-gcp.sh` (para Google Cloud Platform)
   - `asterisk.sh` (para configuración de Asterisk PBX)

### Paso 2: Dar permisos de ejecución

```bash
sudo chmod u+x odoo16-local.sh     # Para entorno local
sudo chmod u+x odoo16-gcp.sh       # Para GCP
sudo chmod u+x asterisk.sh         # Para Asterisk PBX
```

### Paso 3: Ejecutar en orden

#### 🏠 Para entorno local:
```bash
# 1. Primero ejecutar el script principal de Odoo
./odoo16-local.sh -start

# 2. Luego ejecutar el script de Asterisk
./asterisk.sh
```

#### ☁️ Para Google Cloud Platform:
```bash
# 1. Primero ejecutar el script principal de Odoo
./odoo16-gcp.sh -start

# 2. Luego ejecutar el script de Asterisk
./asterisk.sh
```

> ⚠️ **Orden Importante**: Siempre ejecuta primero el script de Odoo con `-start` y después el script de Asterisk sin parámetros.

## 🎯 Comandos Disponibles (Opcionales)

### Script Principal (odoo16-*.sh)

Una vez completada la instalación inicial, puedes usar estos comandos para gestionar el sistema:

| Comando | Descripción |
|---------|-------------|
| `-start` | 🚀 Inicia el despliegue completo |
| `-stop` | ⏹️ Detiene todos los contenedores |
| `-restart` | 🔄 Reinicia el sistema completo |
| `-backup` | 💾 Crea copia de seguridad |
| `-restore` | 📥 Restaura desde backup |
| `-configure` | ⚙️ Solo configura (sin iniciar) |
| `-status` | 📊 Muestra estado del sistema |

### Ejemplos de gestión:
```bash
# Ver estado actual
./odoo16-local.sh -status

# Crear backup
./odoo16-local.sh -backup

# Reiniciar servicios
./odoo16-local.sh -restart
```

## 🌐 Acceso a las Aplicaciones

Una vez desplegado el sistema:

### 🏠 Entorno Local:
- **Odoo**: http://localhost:8069
- **PostgreSQL**: localhost:5432
- **Asterisk PBX**: localhost:5060

### ☁️ Google Cloud Platform:
- **Odoo**: http://[TU-IP-EXTERNA]:8069
- **PostgreSQL**: [IP-INTERNA]:5432
- **Asterisk PBX**: [TU-IP-EXTERNA]:5060

## 📁 Estructura del Proyecto

```
proyecto/
├── odoo16-local.sh      # Script para entorno local
├── odoo16-gcp.sh        # Script para Google Cloud
├── asterisk.sh          # Configuración Asterisk PBX
├── docker-compose.yml   # (Generado automáticamente)
├── .env                 # Variables de entorno
├── external-addons/     # Módulos personalizados de Odoo
├── asterisk-config/     # Configuración de Asterisk
├── config/              # Archivos de configuración
└── backups/             # Copias de seguridad
```

## ⚙️ Configuración Automática

### 🏠 Entorno Local
- ✅ Instalación automática de dependencias
- ✅ Configuración de Docker y Docker Compose
- ✅ Creación de volúmenes persistentes
- ✅ Base de datos PostgreSQL lista para usar

### ☁️ Google Cloud Platform
- ✅ Todo lo anterior, más:
- ✅ Configuración automática del firewall GCP
- ✅ Detección automática de IP externa
- ✅ Optimizaciones para entorno de nube
- ✅ Configuración de proxy mode

## 🔧 Requisitos del Sistema

### Mínimos:
- **OS**: Ubuntu 18.04+ / Debian 9+ / CentOS 7+
- **RAM**: 2GB mínimo, 4GB recomendado
- **Disco**: 10GB libres mínimo
- **Conectividad**: Acceso a internet para descargas

### Para GCP:
- **Instancia**: e2-medium o superior
- **Firewall**: Puerto 8069 abierto
- **Permisos**: Acceso a metadatos de la instancia

## 📦 Componentes Incluidos

| Servicio | Versión | Puerto | Descripción |
|----------|---------|--------|-------------|
| **Odoo** | 16.0 | 8069 | ERP principal |
| **PostgreSQL** | 13 | 5432 | Base de datos |
| **Asterisk** | Latest | 5060 | PBX/VoIP |

## 🛡️ Seguridad

- 🔐 **Credenciales por defecto**:
  - Usuario BD: `admin`
  - Contraseña BD: `admin`
  - Base de datos: `postgres`

> ⚠️ **Importante**: Cambia las credenciales por defecto en producción editando el archivo `.env`

## 🐛 Solución de Problemas

### Problema: Docker no se inicia
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Problema: Permisos insuficientes
```bash
sudo usermod -aG docker $USER
# Cerrar sesión y volver a entrar
```

### Problema: Puerto 8069 ocupado
```bash
sudo lsof -i :8069
# Terminar proceso que usa el puerto
```

### Problema: No se encuentra IP externa (GCP)
- Verificar que la instancia tiene IP externa asignada
- Comprobar configuración de firewall en GCP Console

## 📚 Documentación Adicional

- [Documentación Oficial de Odoo](https://www.odoo.com/documentation/16.0/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/13/)
- [Asterisk Documentation](https://www.asterisk.org/get-started/)

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 📞 Soporte

Si encuentras algún problema o tienes preguntas:

- 🐛 **Issues**: [GitHub Issues](../../issues)
- 📧 **Email**: [i22prpaj@uco.es] **o** [i22jicof@uco.es]
- 💬 **Discusiones**: [GitHub Discussions](../../discussions)

## ⭐ ¿Te ha sido útil?

Si este proyecto te ha ayudado, ¡dale una estrella! ⭐

---

<div align="center">

**🛠️ Hecho con ❤️ para la comunidad Odoo**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)
[![Shell Script](https://img.shields.io/badge/Shell-Script-121011?style=flat&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

*Si este proyecto te ha ayudado, ¡considera darle una ⭐!*

</div>
