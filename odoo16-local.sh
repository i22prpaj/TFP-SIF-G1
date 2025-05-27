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
                                                          
                                                     
"

echo -e "$art_ascii\n"

# Función para verificar si Odoo está instalado
check_odoo_installation() {
    local odoo_home="/opt/odoo16"
    local odoo_service="/etc/systemd/system/odoo16.service"
    local odoo_config="/etc/odoo16.conf"
    
    if [ -d "$odoo_home/odoo-server" ] && [ -f "$odoo_service" ] && [ -f "$odoo_config" ]; then
        return 0  # Odoo está instalado
    else
        return 1  # Odoo no está instalado
    fi
}

# Función para instalar Docker
install_docker() {
    echo "[+] Instalando Docker..."
    sudo apt update
    if [ "$?" -ne 0 ]
    then
        echo -e "\n[-] Ha surgido un error en la actualización de paquetes\n"
        echo -e "[-] Porfavor descarga docker para tu sistema operativo\n"
        exit -1
    fi

    sudo apt-get install docker.io -y
    sudo apt install docker.io -y
    if [ "$?" -ne 0 ]
    then
        echo -e "\n[-] Ha surgido un error en la descarga de docker\n"
        echo -e "[-] Porfavor descarga docker para tu sistema operativo\n"
        exit -1
    fi
}

# Función para instalar Docker Compose
install_docker_compose() {
    echo "[+] Instalando Docker Compose..."
    sudo apt update
    if [ "$?" -ne 0 ]
    then
        echo -e "\n[-] Ha surgido un error en la actualización de paquetes\n"
        echo -e "[-] Porfavor descarga docker-compose para tu sistema operativo\n"
        exit -1
    fi

    sudo apt install docker-compose -y
    if [ "$?" -ne 0 ]
    then
        echo -e "\n[-] Ha surgido un error en la descarga de docker\n"
        echo -e "[-] Porfavor descarga docker-compose para tu sistema operativo\n"
        exit -1
    fi
}

install_postgreesql() {
    echo "[+] Instalando PostgreeSQL..."
    sudo apt update
    if [ "$?" -ne 0 ]
    then
        echo -e "\n[-] Ha surgido un error en la actualización de paquetes\n"
        echo -e "[-] Porfavor descarga PostgreeSQL para tu sistema operativo\n"
        exit -1
    fi

    sudo apt install postgresql -y
    if [ "$?" -ne 0 ]
    then
        echo -e "\n[-] Ha surgido un error en la descarga de docker\n"
        echo -e "[-] Porfavor descarga PostgreeSQL para tu sistema operativo\n"
        exit -1
    fi
}

# Función para lanzar el contenedor
start_container() {
    if systemctl is-active --quiet docker; then
        echo "✅Docker está activo."
    else
        echo "Docker no está activo. Iniciando Docker..."
        start_daemon
    fi

    echo -e "[+] Lanzando el contenedor con docker-compose up...\n"
    docker-compose up -d

    if [ "$?" -eq 0 ]
    then
        echo -e "Para instalar un módulo muévelo al directorio external-addons\n"
        echo -e "[+] Volumen de instalación de addons creado con éxito...\n"

        echo -e "[+] Contenedor odoo-uco lanzado con éxito...\n"
        echo -e "http://localhost:8069\n"
    else
        echo -e "\n[-] Ha surgido un error en el lanzamiento\n"
        exit -1
    fi
    
    docker ps
}

# Función para detener el contenedor
stop_container() {
    echo -e "[+] Deteniendo el contenedor con docker-compose down...\n"
    sudo docker-compose -f docker-compose.yml down

    if [ "$?" -eq 0 ]
    then
        echo -e "\n[+] Contenedor odoo-uco finalizado con éxito...\n" 
        else
            echo -e "\n[-] Ha surgido un error en la finalización\n"
            exit -1
    fi

    docker ps

    stop_daemon
}

restart_container() {
    echo -e "[+] Deteniendo el contenedor con docker-compose down...\n"
    sudo docker-compose -f docker-compose.yml down

    if [ "$?" -eq 0 ]
    then
        echo -e "\n[+] Contenedor odoo-uco finalizado con éxito...\n" 
        else
            echo -e "\n[-] Ha surgido un error en la finalización\n"
            exit -1
    fi

    echo -e "[+] Lanzando el contenedor con docker-compose up...\n"
    sudo docker-compose -f docker-compose.yml up -d

    if [ "$?" -eq 0 ]
    then
        echo -e "Para instalar un módulo muévelo al directorio external-addons\n"
        echo -e "[+] Volumen de instalación de addons creado con éxito...\n"

        echo -e "[+] Contenedor odoo-uco lanzado con éxito...\n"
        echo -e "http://localhost:8069\n"
    else
        echo -e "\n[-] Ha surgido un error en el lanzamiento\n"
        exit -1
    fi
    
    docker ps
}

start_daemon() {
    echo -e "[+] Encendiendo el demonio de docker con systemctl...\n"
    sudo systemctl start docker

    if [ "$?" -eq 0 ]
    then
        echo -e "[+] Demonio encendido exitósamente...\n" 
        else
            echo -e "[-] Ha surgido un error en el inicio del demonio Docker\n"
            exit -1
    fi
}

stop_daemon() {
    echo -e "[+] Deteniendo el demonio de docker con systemctl...\n"
    sudo systemctl stop docker

    if [ "$?" -eq 0 ]
    then
        echo -e "[+] Demonio detenido exitósamente...\n" 
        else
            echo -e "[-] Ha surgido un error en la detención del demonio Docker\n"
            exit -1
    fi
}

make_backup() {
    echo -e "[+] Haciendo copia de seguridad...\n"
    if [ -f backup_postgres.sql ]
    then
        mv backup_postgres.sql backup_postgres_ant.sql
    fi

    sudo docker-compose exec postgres pg_dumpall -U admin > backup_postgres.sql

    if [ "$?" -eq 0 ]
    then
        echo -e "[+] Copia de seguridad creada con exito...\n"

        name=backup_$(date '+%d-%m-%Y_%H-%M')_manual.sql

        cp backup_postgres.sql ./backups/"$name"

        if [ -f backup_postgres_ant.sql ]
        then
            echo -e "[+] Eliminando copia de seguridad antigua de config/...\n"
            rm backup_postgres_ant.sql
        fi
        else
            echo -e "[-] Ha surgido un error en la creación de la copia de seguridad\n"
            if [ -f backup_postgres_ant.sql ]
            then
                echo -e "[-] Manteniendo ultima copia de seguridad\n"
                if [ -f backup_postgres.sql ]
                then
                    rm backup_postgres.sql
                fi
                mv backup_postgres_ant.sql backup_postgres.sql
            fi
            exit -1
    fi
    cd ..
}

restore_backup() {
    echo -e "[/] ¿Estas seguro de querer restaurar todo?"
    read -p "[/] Perderas todo el progreso que no se haya guardado [y/N]:  " opc

    if [[ "$opc" == "y" || "$opc" == "Y" ]]
    then
        echo -e "\n[/] Elige que backup utilizar (ruta relativa)"
        read -p "[/] Por omisión config/backup_postgres.sql (Ultima Creada):  " back

        if [ "$back" == "" ]
        then
            back=config/backup_postgres.sql
        fi
        if [ ! -f "$back" ]
        then
            echo -e "\n[-] El fichero $back no existe\n"
            exit -1
        fi

        echo -e "\n[+] Restaurando copia de seguridad...\n"
        echo -e "[+] Eliminando base de datos anteriór...\n"
        cd config

        sudo docker-compose down --rmi all -v
        if [ "$?" -ne 0 ]
        then
            echo -e "[-] Ha surgido un error en el borrado de la BBDD anterior\n"
            exit -1
        fi
        cd ..

        start_container

        echo -e "[+] Restaurando base de datos...\n"
        sleep 5
        cat "$back" | sudo docker-compose -f config/docker-compose.yml exec -T postgres psql -U admin -d postgres
        if [ "$?" -ne 0 ]
        then
            echo -e "[-] Ha surgido un error en la restauración de la BBDD\n"
            exit -1
        fi
        echo -e "[+] Restauración realizada con éxito...\n"

        else
            echo -e "[+] Cancelando restauración de la copia de seguridad...\n"
    fi
}

install_odoo() {
    echo "[+] Instalando Odoo..."

    # Variables
    ODOO_USER="odoo16"
    ODOO_HOME="/opt/$ODOO_USER"
    ODOO_VERSION="16.0"
    ODOO_PORT="8069"
    ODOO_CONFIG="/etc/${ODOO_USER}.conf"
    ODOO_LOG="/var/log/${ODOO_USER}"
    ODOO_DB_USER="$ODOO_USER"
    ODOO_DB_PASSWORD="odoo16pass"

    # Actualizar el sistema
    sudo apt update && sudo apt upgrade -y

    # Crear usuario del sistema
    sudo useradd -m -d $ODOO_HOME -U -r -s /bin/bash $ODOO_USER

    # Instalar dependencias
    sudo apt install -y git python3-pip build-essential wget python3-dev python3-venv \
    python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools \
    node-less libjpeg-dev zlib1g-dev libpq-dev libxslt1-dev libldap2-dev libtiff5-dev \
    libopenjp2-7-dev npm

    # Instalar y configurar PostgreSQL
    sudo apt install -y postgresql
    sudo su - postgres -c "createuser -s $ODOO_DB_USER"

    # Instalar wkhtmltopdf
    sudo apt install -y xfonts-75dpi xfonts-base
    wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
    sudo dpkg -i wkhtmltox_0.12.6.1-2.jammy_amd64.deb
    rm wkhtmltox_0.12.6.1-2.jammy_amd64.deb

    # Crear directorios necesarios
    sudo mkdir -p $ODOO_LOG
    sudo chown $ODOO_USER:$ODOO_USER $ODOO_LOG

    # Clonar Odoo desde GitHub
    sudo git clone --depth 1 --branch $ODOO_VERSION https://www.github.com/odoo/odoo $ODOO_HOME/odoo-server
    sudo chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME

    # Crear entorno virtual de Python e instalar dependencias
    sudo su - $ODOO_USER -c "
    cd $ODOO_HOME/odoo-server
    python3 -m venv venv
    source venv/bin/activate
    pip3 install wheel
    pip3 install -r requirements.txt
    deactivate
    "

    # Crear archivo de configuración de Odoo
    sudo bash -c 'cat > /etc/odoo16.conf <<EOF
[options]
; This is the password that allows database operations:
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo16
db_password = False
addons_path = /opt/odoo16/odoo-server/addons
logfile = /var/log/odoo/odoo16.log
xmlrpc_port = 8069
'

    sudo chown $ODOO_USER:$ODOO_USER $ODOO_CONFIG
    sudo chmod 640 $ODOO_CONFIG

    # Crear servicio systemd para Odoo
    sudo bash -c 'cat > /etc/systemd/system/odoo16.service <<EOF
[Unit]
Description=Odoo16
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo16
PermissionsStartOnly=true
User=odoo16
Group=odoo16
ExecStart=/opt/odoo16/odoo-server/venv/bin/python3 /opt/odoo16/odoo-server/odoo-bin -c /etc/odoo16.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
'

    # Recargar daemon y habilitar servicio
    sudo systemctl daemon-reload
    sudo systemctl enable $ODOO_USER
    sudo systemctl start $ODOO_USER

    # Crear archivo docker-compose.yml
    sudo bash -c 'cat > docker-compose.yml << EOF
services:
  odoo:
    image: odoo:16.0
    env_file: .env
    depends_on:
       - postgres
    ports:
       - "8069:8069"
       - "4573:4573"
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
      DB_USER: admin
      DB_PASSWORD: admin
      DB_NAME: postgres
      
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
'
    echo "✅ docker-compose.yml creado correctamente en: $(pwd)/"

    #Crear .env
    sudo bash -c 'cat > .env << EOF
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
'

    echo "✅ .env creado correctamente en: $(pwd)/"

    echo -e "$art_ascii\n"

    echo "--------------------------------------------------"
    echo "✅¡Odoo 16 ha sido instalado y está en ejecución!"
    echo "--------------------------------------------------"

}

# === VERIFICACIONES DE INSTALACIÓN ===

# Comprobar si Odoo está instalado usando la función optimizada
if check_odoo_installation; then
    echo "✅ Odoo 16 ya está instalado y configurado."
else
    echo "⚠️  Odoo 16 no está instalado. Procediendo con la instalación..."
    install_odoo
fi

# Comprobar si postgresql está instalado
if ! command -v psql &> /dev/null; then
    echo "⚠️  PostgreSQL no está instalado. Procediendo con la instalación..."
    install_postgreesql
else
    echo "✅ PostgreSQL ya está instalado."
fi

# Comprobar si docker está instalado
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker no está instalado. Procediendo con la instalación..."
    install_docker
else
    echo "✅ Docker ya está instalado."
fi

# Comprobar si docker-compose está instalado
if ! command -v docker-compose &> /dev/null; then
    echo "⚠️  Docker Compose no está instalado. Procediendo con la instalación..."
    install_docker_compose
else
    echo "✅ Docker Compose ya está instalado."
fi

# Comprobar si Docker Daemon esta activo
if systemctl is-active --quiet docker; then
    echo "✅ Docker está activo."
else
    echo "⚠️  Docker no está activo. Iniciando Docker..."
    start_daemon
fi

# Comprobar opción elegida
if [ "$1" == "-start" ]; then
    # Esperar a que exista el archivo docker-compose.yml
    echo "[🔄] Esperando a que se cree el archivo docker-compose.yml..."

    while [ ! -f docker-compose.yml ]; do
        sleep 1
    done

    echo "[✅] docker-compose.yml encontrado. Iniciando contenedores..."
    start_container

elif [ "$1" == "-stop" ]; then
    stop_container

elif [ "$1" == "-restart" ]; then
    restart_container

elif [ "$1" == "-backup" ]
then
    make_backup

elif [ "$1" == "-restore" ]
then
    restore_backup

else
    echo "Uso: $0 { -start | -stop | -backup | -restore }"
    echo "  -start: Inicia el despliegue del contenedor"
    echo "  -stop: Detiene la ejecución del contenedor"
    echo "  -restart: Reinicia el contenedor"
    echo "  -backup: Hace una copia de seguridad de todo"
    echo "  -restore: Restaura una copia de seguridad creada"
    exit 1
fi