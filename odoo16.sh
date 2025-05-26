#!/bin/bash

# Detectar sistema operativo y limpiar pantalla
if [ "$OSTYPE" == "msys" ] || [ "$OSTYPE" == "win32" ]; then
    cls
else
    clear
fi

# Arte ASCII
art_ascii="

    ████████╗███████╗██████╗               ███████╗██╗███████╗
    ╚══██╔══╝██╔════╝██╔══██╗              ██╔════╝██║██╔════╝
       ██║   █████╗  ██████╔╝    █████╗    ███████╗██║█████╗  
       ██║   ██╔══╝  ██╔═══╝     ╚════╝    ╚════██║██║██╔══╝  
       ██║   ██║     ██║                   ███████║██║██║     
       ╚═╝   ╚═╝     ╚═╝                   ╚══════╝╚═╝╚═╝                                                                                                                                                                                                                                                                               
                                                                                    
      ██████╗ ██████╗ ██╗   ██╗██████╗  ██████╗      ██╗
     ██╔════╝ ██╔══██╗██║   ██║██╔══██╗██╔═══██╗    ███║
     ██║  ███╗██████╔╝██║   ██║██████╔╝██║   ██║    ╚██║
     ██║   ██║██╔══██╗██║   ██║██╔═══╝ ██║   ██║     ██║
     ╚██████╔╝██║  ██║╚██████╔╝██║     ╚██████╔╝     ██║
      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝      ╚═════╝      ╚═╝
                                                          
                        GCP EDITION                    
"

echo -e "$art_ascii\n"

# Función para verificar si Odoo ya está configurado
is_odoo_configured() {
    # Verificar si existe docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        return 1
    fi
    
    # Verificar si existe el archivo .env
    if [ ! -f ".env" ]; then
        return 1
    fi
    
    # Verificar si existe el directorio external-addons
    if [ ! -d "external-addons" ]; then
        return 1
    fi
    
    # Verificar si los contenedores existen (aunque estén parados)
    if ! sudo docker-compose ps -q odoo >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Función para verificar si Odoo está ejecutándose
is_odoo_running() {
    if sudo docker-compose ps | grep -q "odoo.*Up"; then
        return 0
    else
        return 1
    fi
}

# Obtener la IP externa de la instancia de GCP
get_external_ip() {
    # Intentar obtener la IP pública usando el servicio de metadatos de GCP
    EXTERNAL_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null)
    
    # Si no podemos obtenerla del servicio de metadatos, intentar con curl a un servicio externo
    if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" == "null" ]; then
        EXTERNAL_IP=$(curl -s https://api.ipify.org 2>/dev/null)
    fi
    
    # Si aún no tenemos la IP, usar una dirección genérica
    if [ -z "$EXTERNAL_IP" ]; then
        EXTERNAL_IP="<TU-IP-PUBLICA>"
        echo "[!] No se pudo determinar la IP pública automáticamente."
        echo "[!] Por favor reemplaza <TU-IP-PUBLICA> con la IP externa de tu instancia GCP."
    fi
    
    echo "$EXTERNAL_IP"
}

# Configurar reglas de firewall de GCP
configure_gcp_firewall() {
    echo "[+] Configurando firewall para permitir tráfico al puerto 8069..."
    
    # Verificar si gcloud está instalado
    if command -v gcloud &> /dev/null; then
        # Si el usuario tiene gcloud configurado, intentamos crear la regla de firewall
        INSTANCE_NAME=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name 2>/dev/null)
        PROJECT_ID=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id 2>/dev/null)
        
        if [ -n "$INSTANCE_NAME" ] && [ -n "$PROJECT_ID" ]; then
            echo "[+] Intentando configurar regla de firewall con gcloud..."
            gcloud compute firewall-rules create allow-odoo --allow tcp:8069 --target-tags=http-server --project=$PROJECT_ID 2>/dev/null || echo "[!] Regla de firewall ya existe o no se pudo crear"
            gcloud compute instances add-tags $INSTANCE_NAME --tags=http-server --project=$PROJECT_ID 2>/dev/null || echo "[!] Tag ya existe o no se pudo añadir"
        fi
    else
        echo "[!] gcloud no está instalado o no se puede acceder a los metadatos de la instancia"
        echo "[!] Por favor, asegúrate de crear una regla de firewall manualmente:"
        echo "[!] 1. Ve a GCP Console > VPC Network > Firewall"
        echo "[!] 2. Crea una regla que permita tráfico TCP al puerto 8069 para tu instancia"
    fi
    
    # Abrir puerto en el firewall local de Ubuntu
    sudo ufw allow 8069/tcp 2>/dev/null || echo "[!] No se pudo configurar UFW o ya está configurado"
    
    echo "[+] Configuración de firewall completada"
}

# Función para instalar Docker
install_docker() {
    echo "[+] Instalando Docker..."
    sudo apt update
    if [ "$?" -ne 0 ]; then
        echo -e "\n[-] Ha surgido un error en la actualización de paquetes\n"
        echo -e "[-] Por favor descarga docker para tu sistema operativo\n"
        exit 1
    fi

    sudo apt-get install docker.io -y
    if [ "$?" -ne 0 ]; then
        echo -e "\n[-] Ha surgido un error en la descarga de docker\n"
        echo -e "[-] Por favor descarga docker para tu sistema operativo\n"
        exit 1
    fi
    
    # Añadir usuario actual al grupo docker para no necesitar sudo
    sudo usermod -aG docker $USER
    echo "[!] Se ha añadido el usuario actual al grupo docker."
    echo "[!] Es posible que necesites cerrar sesión y volver a entrar para que tenga efecto."
}

# Función para instalar Docker Compose
install_docker_compose() {
    echo "[+] Instalando Docker Compose..."
    sudo apt update
    if [ "$?" -ne 0 ]; then
        echo -e "\n[-] Ha surgido un error en la actualización de paquetes\n"
        echo -e "[-] Por favor descarga docker-compose para tu sistema operativo\n"
        exit 1
    fi

    sudo apt install docker-compose -y
    if [ "$?" -ne 0 ]; then
        echo -e "\n[-] Ha surgido un error en la descarga de docker-compose\n"
        echo -e "[-] Por favor descarga docker-compose para tu sistema operativo\n"
        exit 1
    fi
}

# Función para crear/actualizar docker-compose.yml con configuraciones para GCP
setup_odoo_configuration() {
    echo "[+] Configurando Odoo para GCP..."
    
    if [ ! -d "config" ]; then
        mkdir -p config
    fi
    
    cat > docker-compose.yml << EOF
services:
  odoo:
    image: odoo:16.0
    env_file: .env
    depends_on:
       - postgres
    ports:
       - "8069:8069"
    volumes:
       - data:/var/lib/odoo
       - ./external-addons:/mnt/extra-addons
    restart: always
    container_name: odoo
    networks:
      - odoo-net
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: \${POSTGRES_USER}
      DB_PASSWORD: \${POSTGRES_PASSWORD}
      DB_NAME: \${POSTGRES_DB}
      # Configuración para GCP
      PROXY_MODE: "true"
      LIST_DB: "true"
      
  postgres:
    image: postgres:13
    env_file: .env
    volumes:
      - db:/var/lib/postgresql/data/pgdata
    restart: always
    container_name: postgres
    networks:
      - odoo-net

  asterisk:
    image: mlan/asterisk
    container_name: asterisk
    restart: always
    ports:
      - "5060:5060/udp"
      - "5060:5060/tcp"
      - "5038:5038"                    # AMI
      - "8088:8088"                    # ARI (HTTP/8088)
      - "10000-10100:10000-10100/udp"  # RTP media streams
    volumes:
      - ./asterisk-config:/etc/asterisk
    networks:
      - odoo-net

volumes:
  data:
  db:

networks:
  odoo-net:
    driver: bridge
EOF

    # Crear .env
    cat > .env << EOF
# variables de entorno postgresql
POSTGRES_DB=postgres
POSTGRES_PASSWORD=admin
POSTGRES_USER=admin
PGDATA=/var/lib/postgresql/data/pgdata
# variables de entorno odoo
HOST=postgres
USER=admin
PASSWORD=admin
# Variables de entorno para Odoo
DB_HOST=postgres
DB_PORT=5432
DB_USER=admin
DB_PASSWORD=admin
DB_NAME=postgres
# Configuraciones adicionales para GCP
PROXY_MODE=true
EOF

    # Asegurar que existe el directorio para add-ons
    if [ ! -d "external-addons" ]; then
        mkdir -p external-addons
        echo "[+] Directorio external-addons creado"
    fi
    
    # Asegurar que existe el directorio para configuración de Asterisk
    if [ ! -d "asterisk-config" ]; then
        mkdir -p asterisk-config
        echo "[+] Directorio asterisk-config creado"
    fi
    
    echo "[+] Configuración de Odoo completada"
}

# Función para lanzar el contenedor
start_container() {
    # Verificar si Odoo ya está configurado
    if ! is_odoo_configured; then
        echo "[!] Odoo no está configurado. Configurando ahora..."
        setup_odoo_configuration
        configure_gcp_firewall
    fi
    
    # Verificar si ya está ejecutándose
    if is_odoo_running; then
        echo "[!] Odoo ya está ejecutándose"
        EXTERNAL_IP=$(get_external_ip)
        echo -e "Accede a Odoo desde: http://$EXTERNAL_IP:8069\n"
        docker ps
        return 0
    fi
    
    echo -e "[+] Lanzando el contenedor con docker-compose up...\n"
    sudo docker-compose -f docker-compose.yml up -d

    if [ "$?" -eq 0 ]; then
        EXTERNAL_IP=$(get_external_ip)
        echo -e "Para instalar un modulo muévelo al directorio external-addons\n"
        echo -e "[+] Volumen de instalación de addons creado con éxito...\n"
        echo -e "[+] Contenedor odoo lanzado con éxito...\n"
        echo -e "Accede a Odoo desde: http://$EXTERNAL_IP:8069\n"
    else
        echo -e "\n[-] Ha surgido un error en el lanzamiento\n"
        exit 1
    fi

    docker ps
}

# Función para detener el contenedor
stop_container() {
    if ! is_odoo_running; then
        echo "[!] Odoo no está ejecutándose"
        return 0
    fi
    
    echo -e "[+] Deteniendo el contenedor con docker-compose down...\n"
    sudo docker-compose -f docker-compose.yml down

    if [ "$?" -eq 0 ]; then
        echo -e "\n[+] Contenedor odoo finalizado con éxito...\n" 
    else
        echo -e "\n[-] Ha surgido un error en la finalización\n"
        exit 1
    fi
}

restart_container() {
    echo -e "[+] Reiniciando contenedores...\n"
    
    if is_odoo_running; then
        stop_container
    fi
    
    start_container
}

start_daemon() {
    echo -e "[+] Encendiendo el demonio de docker con systemctl...\n"
    sudo systemctl start docker

    if [ "$?" -eq 0 ]; then
        echo -e "[+] Demonio encendido exitósamente...\n" 
    else
        echo -e "[-] Ha surgido un error en el inicio del demonio Docker\n"
        exit 1
    fi
}

make_backup() {
    if ! is_odoo_running; then
        echo "[-] Odoo no está ejecutándose. No se puede hacer backup."
        echo "[!] Inicia Odoo primero con: $0 -start"
        exit 1
    fi
    
    echo -e "[+] Haciendo copia de seguridad...\n"
    if [ ! -d "config" ]; then
        mkdir -p config
    fi
    if [ ! -d "backups" ]; then
        mkdir -p backups
    fi
    
    cd config
    if [ -f backup_postgres.sql ]; then
        mv backup_postgres.sql backup_postgres_ant.sql
    fi

    sudo docker-compose exec postgres pg_dumpall -U admin > backup_postgres.sql

    if [ "$?" -eq 0 ]; then
        echo -e "[+] Copia de seguridad creada con éxito...\n"

        name=backup_$(date '+%d-%m-%Y_%H-%M')_manual.sql

        cp backup_postgres.sql ../backups/"$name"

        if [ -f backup_postgres_ant.sql ]; then
            echo -e "[+] Eliminando copia de seguridad antigua de config/...\n"
            rm backup_postgres_ant.sql
        fi
    else
        echo -e "[-] Ha surgido un error en la creación de la copia de seguridad\n"
        if [ -f backup_postgres_ant.sql ]; then
            echo -e "[-] Manteniendo última copia de seguridad\n"
            if [ -f backup_postgres.sql ]; then
                rm backup_postgres.sql
            fi
            mv backup_postgres_ant.sql backup_postgres.sql
        fi
        exit 1
    fi
    cd ..
}

restore_backup() {
    echo -e "[/] ¿Estás seguro de querer restaurar todo?"
    read -p "[/] Perderás todo el progreso que no se haya guardado [y/N]:  " opc

    if [[ "$opc" == "y" || "$opc" == "Y" ]]; then
        echo -e "\n[/] Elige qué backup utilizar (ruta relativa)"
        read -p "[/] Por omisión config/backup_postgres.sql (Última Creada):  " back

        if [ "$back" == "" ]; then
            back=config/backup_postgres.sql
        fi
        if [ ! -f "$back" ]; then
            echo -e "\n[-] El fichero $back no existe\n"
            exit 1
        fi

        echo -e "\n[+] Restaurando copia de seguridad...\n"
        echo -e "[+] Eliminando base de datos anterior...\n"

        sudo docker-compose down --rmi all -v
        if [ "$?" -ne 0 ]; then
            echo -e "[-] Ha surgido un error en el borrado de la BBDD anterior\n"
            exit 1
        fi

        start_container

        echo -e "[+] Restaurando base de datos...\n"
        sleep 5
        cat "$back" | sudo docker-compose -f docker-compose.yml exec -T postgres psql -U admin -d postgres
        if [ "$?" -ne 0 ]; then
            echo -e "[-] Ha surgido un error en la restauración de la BBDD\n"
            exit 1
        fi
        echo -e "[+] Restauración realizada con éxito...\n"
    else
        echo -e "[+] Cancelando restauración de la copia de seguridad...\n"
    fi
}

show_status() {
    echo "[+] Estado actual del sistema:"
    echo "================================"
    
    if is_odoo_configured; then
        echo "✅ Odoo está configurado"
        if is_odoo_running; then
            echo "✅ Odoo está ejecutándose"
            EXTERNAL_IP=$(get_external_ip)
            echo "🌐 Acceso: http://$EXTERNAL_IP:8069"
        else
            echo "⏸️  Odoo está parado"
        fi
    else
        echo "❌ Odoo no está configurado"
    fi
    
    echo ""
    if command -v docker &> /dev/null; then
        echo "✅ Docker está instalado"
    else
        echo "❌ Docker no está instalado"
    fi
    
    if command -v docker-compose &> /dev/null; then
        echo "✅ Docker Compose está instalado"
    else
        echo "❌ Docker Compose no está instalado"
    fi
    
    if systemctl is-active --quiet docker; then
        echo "✅ Docker está activo"
    else
        echo "❌ Docker no está activo"
    fi
    
    echo ""
    echo "Contenedores:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No se pueden mostrar los contenedores"
}

# Verificación inicial de dependencias
echo "[+] Verificando dependencias..."

# Comprobar si docker está instalado
if ! command -v docker &> /dev/null; then
    install_docker
else
    echo "✅ Docker ya está instalado"
fi

# Comprobar si docker-compose está instalado
if ! command -v docker-compose &> /dev/null; then
    install_docker_compose
else
    echo "✅ Docker Compose ya está instalado"
fi

# Comprobar si Docker Daemon está activo
if systemctl is-active --quiet docker; then
    echo "✅ Docker está activo"
else
    echo "[!] Docker no está activo. Iniciando Docker..."
    start_daemon
fi

# Verificar configuración de Odoo
if is_odoo_configured; then
    echo "✅ Odoo ya está configurado"
else
    echo "[!] Odoo no está configurado (se configurará automáticamente al iniciar)"
fi

# Comprobar opción elegida
if [ "$1" == "-start" ]; then
    start_container

elif [ "$1" == "-stop" ]; then
    stop_container

elif [ "$1" == "-restart" ]; then
    restart_container

elif [ "$1" == "-backup" ]; then
    make_backup

elif [ "$1" == "-restore" ]; then
    restore_backup

elif [ "$1" == "-configure" ]; then
    setup_odoo_configuration
    configure_gcp_firewall
    EXTERNAL_IP=$(get_external_ip)
    echo "[+] Configuración completada. La aplicación estará disponible en: http://$EXTERNAL_IP:8069"

elif [ "$1" == "-status" ]; then
    show_status

else
    echo "Uso: $0 { -start | -stop | -restart | -backup | -restore | -configure | -status }"
    echo "  -start: Inicia el despliegue del contenedor (configura automáticamente si es necesario)"
    echo "  -stop: Detiene la ejecución del contenedor"
    echo "  -restart: Reinicia el contenedor"
    echo "  -backup: Hace una copia de seguridad de todo"
    echo "  -restore: Restaura una copia de seguridad creada"
    echo "  -configure: Configura Odoo para GCP (sin iniciar)"
    echo "  -status: Muestra el estado actual del sistema"
    exit 1
fi

# Fin del script
echo -e "\n[+] Script finalizado con éxito...\n"