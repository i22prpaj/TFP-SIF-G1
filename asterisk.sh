#!/bin/bash

# Detectar sistema operativo y limpiar pantalla
if [ "$OSTYPE" == "msys" ] || [ "$OSTYPE" == "win32" ]; then
    cls
else
    clear
fi

# Arte ASCII
art_ascii="
     ██████╗ ██████╗  ██████╗  ██████╗       ██████╗ █████╗ ██╗     ██╗         
    ██╔═══██╗██╔══██╗██╔═══██╗██╔═══██╗     ██╔════╝██╔══██╗██║     ██║         
    ██║   ██║██║  ██║██║   ██║██║   ██║     ██║     ███████║██║     ██║         
    ██║   ██║██║  ██║██║   ██║██║   ██║     ██║     ██╔══██║██║     ██║         
    ╚██████╔╝██████╔╝╚██████╔╝╚██████╔╝     ╚██████╗██║  ██║███████╗███████╗    
     ╚═════╝ ╚═════╝  ╚═════╝  ╚═════╝       ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝    

     ██████╗███████╗███╗   ██╗████████╗███████╗██████╗
    ██╔════╝██╔════╝████╗  ██║╚══██╔══╝██╔════╝██╔══██╗
    ██║     █████╗  ██╔██╗ ██║   ██║   █████╗  ██████╔╝    VOIP EDITION
    ██║     ██╔══╝  ██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗
    ╚██████╗███████╗██║ ╚████║   ██║   ███████╗██║  ██║
     ╚═════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
"

echo -e "$art_ascii\n"

# Comprobar si está ejecutando como root o con sudo
if [ "$EUID" -ne 0 ]; then
    echo "[!] Este script requiere privilegios de administrador"
    echo "[!] Por favor ejecute: sudo $0"
    exit 1
fi

# Variables globales
ODOO_ADDONS_DIR="external-addons"
REQUIRED_MODULES=("asterisk_plus" "base_phone")
ASTERISK_CONF_DIR="/etc/asterisk"
WORKING_DIR=$(pwd)
TEMP_DIR="/tmp/odoo_call_center_setup"

# Obtener la IP externa de la instancia
get_external_ip() {
    # Intentar obtener la IP pública usando curl a un servicio externo
    EXTERNAL_IP=$(curl -s https://api.ipify.org 2>/dev/null)
    
    # Si aún no tenemos la IP, pedir al usuario
    if [ -z "$EXTERNAL_IP" ]; then
        read -p "[?] No se pudo determinar la IP pública automáticamente. Por favor, ingrese la IP externa de su instancia: " EXTERNAL_IP
    fi
    
    echo "$EXTERNAL_IP"
}

# Verificar la existencia de los módulos requeridos
check_required_modules() {
    echo "[+] Verificando módulos requeridos..."
    local missing_modules=()
    
    for module in "${REQUIRED_MODULES[@]}"; do
        if [ ! -d "$ODOO_ADDONS_DIR/$module" ]; then
            missing_modules+=("$module")
        else
            echo "[✓] Módulo $module encontrado en $ODOO_ADDONS_DIR"
        fi
    done
    
    if [ ${#missing_modules[@]} -gt 0 ]; then
        echo "[!] Faltan los siguientes módulos: ${missing_modules[*]}"
        echo "[!] Por favor, asegúrese de que estos módulos estén en la carpeta $ODOO_ADDONS_DIR"
        
        read -p "¿Desea continuar de todos modos? (y/n): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            echo "[!] Instalación abortada."
            exit 1
        fi
    fi
}

# Instalar dependencias del sistema
install_system_dependencies() {
    echo "[+] Instalando dependencias del sistema..."
    
    apt update
    apt install -y asterisk asterisk-modules asterisk-core-sounds-en-gsm gnupg2 wget lsb-release curl python3-pip
    
    if [ $? -ne 0 ]; then
        echo "[-] Error instalando dependencias del sistema."
        exit 1
    fi
    
    # Instalar dependencias de Python para los módulos
    pip3 install phonenumbers py-Asterisk
    
    echo "[✓] Dependencias del sistema instaladas correctamente"
}

# Configurar Asterisk
configure_asterisk() {
    echo "[+] Configurando Asterisk..."
    
    # Configurar Asterisk Manager Interface (AMI) para Odoo
    echo "[+] Configurando Asterisk Manager Interface (AMI)..."
    cat > "$ASTERISK_CONF_DIR/manager.conf" << EOF
[general]
enabled  = yes
port     = 5038
bindaddr = 0.0.0.0
bindport = 8088

[admin]
secret = admin
read = all
write = all
EOF

    # Configurar SIP para Zadarma
    echo "[+] Configurando SIP..."
    cat > "$ASTERISK_CONF_DIR/sip.conf" << EOF
[general]
context=default
allowoverlap=no
udpbindaddr=0.0.0.0
tcpenable=no
tcpbindaddr=0.0.0.0
transport=udp
srvlookup=yes
allowguest=no
alwaysauthreject=yes
canreinvite=no
nat=force_rport,comedia
session-timers=refuse
dtmfmode=rfc2833
disallow=all
allow=ulaw
allow=alaw
allow=gsm
videosupport=yes
maxexpiry=3600
minexpiry=60
defaultexpiry=3600
rtptimeout=60
rtpholdtimeout=300

; Registro con Zadarma
[zadarma]
type=friend
host=sip.zadarma.com
fromuser=908733
secret=118bGuzuEt
context=from-zadarma
dtmfmode=rfc2833
disallow=all
allow=ulaw
allow=alaw
allow=gsm
nat=force_rport,comedia
qualify=yes
canreinvite=no
EOF

    # Configurar plan de marcado (dialplan)
    echo "[+] Configurando plan de marcado..."
    cat > "$ASTERISK_CONF_DIR/extensions.conf" << EOF
[general]
static=yes
writeprotect=no
autofallthrough=yes
priorityjumping=no
extenpatternmatchnew=yes

[globals]
TRUNK_ENDPOINT = zadarma-endpoint
CONTRY_CODE = 34   ; Spain country code
DIAL_TIMEOUT = ,30 ; Timeout for dial operations

[default]
; Extensión 1001 (Administrador)
exten => 1001,1,NoOp(Llamada entrante para 1001 - Administrador)
exten => 1001,n,Set(CALLERID(name)=Administrador)
exten => 1001,n,Dial(PJSIP/1001,20)
exten => 1001,n,Hangup()

; Extensión 1002 (Usuario Prueba)
exten => 1002,1,NoOp(Llamada entrante para 1002 - Usuario Prueba)
exten => 1002,n,Set(CALLERID(name)=Usuario Prueba)
exten => 1002,n,Dial(PJSIP/1002,20)
exten => 1002,n,Hangup()

; Echo test
exten => 600,1,Answer()
exten => 600,n,Echo()
exten => 600,n,Hangup()

; Contexto para llamadas salientes desde Odoo
exten => _1XXX,1,NoOp(Llamada interna desde \${CALLERID(num)} a \${EXTEN})
exten => _1XXX,n,Set(CDR(userfield)=\${CALLERID(num)})
exten => _1XXX,n,Dial(PJSIP/\${EXTEN},20)
exten => _1XXX,n,Hangup()

; Patrón genérico para otras llamadas
exten => _X.,1,NoOp(Llamada desde \${CALLERID(num)} a \${EXTEN})
exten => _X.,n,Set(CDR(userfield)=\${CALLERID(num)})
exten => _X.,n,Dial(PJSIP/\${EXTEN},20)
exten => _X.,n,Hangup()

[from-zadarma]
exten => _X.,1,NoOp(Llamada entrante desde Zadarma: \${CALLERID(num)} hacia \${EXTEN})
 same => n,Set(CALLERID(name)=\${CALLERID(num)})
 same => n,Answer()
 same => n,Dial(PJSIP/1001,60)
 same => n,Hangup()

[outbound]
exten => _X.,1,NoOp(Llamada saliente hacia \${EXTEN})
 same => n,Set(CALLERID(all)=Odoo <908733>)
 same => n,Dial(PJSIP/zadarma-endpoint/\${EXTEN})
 same => n,Hangup()
EOF

    # Configurar PJSIP
    echo "[+] Configurando PJSIP..."
    cat > "$ASTERISK_CONF_DIR/pjsip.conf" << EOF
[global]
type = global
user_agent = Platform PBX
endpoint_identifier_order = ip,username,anonymous

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=172.27.128.1
external_signaling_address=172.27.128.1

;-------------------------------- Templates ------------------------------------
[endpoint_template](!)
type=endpoint
context=dp_call_inout
disallow=all
allow=ulaw,alaw,g722
direct_media=no
device_state_busy_at=1
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes

[auth_template](!)
type=auth
auth_type=userpass

[aor_template](!)
type=aor
max_contacts=1
remove_existing=yes
qualify_frequency=60

;-------------------------------- Endpoints Internos --------------------------
[1001](endpoint_template)
auth=auth1001
aors=aor1001
callerid=Administrador <1001>
set_var=ODOO_USER=admin

[auth1001](auth_template)
password=clave_segura
username=1001

[aor1001](aor_template)

[1002](endpoint_template)
auth=auth1002
aors=aor1002
callerid=Usuario Prueba <1002>
set_var=ODOO_USER=usuario_prueba

[auth1002](auth_template)
password=password_user_1002
username=1002

[aor1002](aor_template)

;-------------------------------- Zadarma (Trunk) ----------------------------
[zadarma-endpoint](endpoint_template)
transport=transport-udp
outbound_auth=zadarma-auth
aors=zadarma-aor
qualify_timeout = 500

[zadarma-auth](auth_template)
username=908733
password=118bGuzuEt

[zadarma-aor](aor_template)
qualify_frequency = 60

[zadarma-registration]
type=registration
outbound_auth=zadarma-auth
server_uri=sip:sip.zadarma.com:5060
client_uri=sip:908733@sip.zadarma.com
retry_interval=60

[zadarma-ident]
type=identify
endpoint=zadarma-endpoint
match=sip.zadarma.com

;-------------------------------- Identificación por IP ----------------------
[1001-ident]
type=identify
endpoint=1001
match=172.27.128.1
EOF

    # Configurar ARI
    echo "[+] Configurando ARI..."
    cat > "$ASTERISK_CONF_DIR/ari.conf" << EOF
[general]
enabled = yes
pretty = yes
bindaddr = 0.0.0.0
bindport = 8088
allowed_origins = *

[admin]
type = user
read_only = no
password = admin
EOF

    echo "[✓] Asterisk configurado correctamente"
}

# Configurar permisos adecuados para los módulos
set_permissions() {
    echo "[+] Configurando permisos para los módulos..."
    chmod -R 755 "$ODOO_ADDONS_DIR"
    chown -R 1000:1000 "$ODOO_ADDONS_DIR"  # UID:GID típico para el usuario odoo en el contenedor
    echo "[✓] Permisos configurados correctamente"
}

# Test de conectividad de Asterisk
test_asterisk_connectivity() {
    echo "[+] Probando conexión con Asterisk..."
    
    # Probar la conectividad al AMI
    echo "[+] Probando conexión al AMI (puerto 5038)..."
    nc -zv localhost 5038 &>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "[✓] Conexión al AMI establecida correctamente"
    else
        echo "[-] Error: No se puede conectar al AMI (puerto 5038)"
        echo "[!] Verifique la configuración de Asterisk y que el servicio esté en ejecución"
    fi
    
    # Probar la conectividad SIP
    echo "[+] Probando conectividad SIP (puerto 5060)..."
    nc -zuv localhost 5060 &>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "[✓] Puerto SIP accesible correctamente"
    else
        echo "[-] Error: No se puede acceder al puerto SIP (5060)"
        echo "[!] Verifique la configuración de Asterisk y que el servicio esté en ejecución"
    fi
}

# Crear SIP hardphone de prueba para verificar funcionamiento
create_test_sip_extension() {
    echo "[+] Creando extensión SIP de prueba..."
    
    # Añadir extensión de prueba al archivo pjsip.conf
    cat >> "$ASTERISK_CONF_DIR/pjsip.conf" << EOF

; Extensión de prueba para verificar funcionamiento
[test_extension](endpoint_template)
auth=test_auth
aors=test_aor
callerid=Test Extension <2000>

[test_auth](auth_template)
password=test_password
username=test_extension

[test_aor](aor_template)
EOF
    
    echo "[✓] Extensión de prueba creada correctamente"
    echo "[i] Datos para configurar un softphone de prueba:"
    echo "    - Servidor: $(get_external_ip)"
    echo "    - Puerto: 5060"
    echo "    - Usuario: test_extension"
    echo "    - Contraseña: test_password"
}

# Función para proporcionar instrucciones después de la instalación
post_install_instructions() {
    EXTERNAL_IP=$(get_external_ip)
    echo ""
    echo "===================================================================="
    echo "          INSTRUCCIONES PARA COMPLETAR LA INTEGRACIÓN DEL           "
    echo "                CALL CENTER DE ODOO CON ZADARMA                     "
    echo "===================================================================="
    echo ""
    echo "1. VERIFICACIÓN DE CONFIGURACIÓN DE ZADARMA:"
    echo "   - Se ha configurado Zadarma con los siguientes datos:"
    echo "     * Usuario: 908733"
    echo "     * Contraseña: 118bGuzuEt"
    echo "     * Servidor: sip.zadarma.com"
    echo ""
    echo "2. ACCESO A ODOO Y ACTIVACIÓN DE MÓDULOS:"
    echo "   - Accede a Odoo y activa los siguientes módulos:"
    echo "     * asterisk_plus"
    echo "     * base_phone"
    echo "     * phone_validation"
    echo ""
    echo "3. CONFIGURACIÓN DE LA INTEGRACIÓN ASTERISK EN ODOO:"
    echo "   - Ve a Ajustes > Técnico > Asterisk Servers"
    echo "   - Configura un nuevo servidor Asterisk con estos datos:"
    echo "     * Nombre: Asterisk"
    echo "     * DNS: asterisk"
    echo "     * Puerto AMI: 5038"
    echo "     * Puerto ARI: 8088"
    echo "     * Usuario AMI/ARI: admin"
    echo "     * Contraseña AMI/ARI: admin"
    echo "     * Prueba la conexión con Asterisk"
    echo ""
    echo "4. CONFIGURACIÓN DE USUARIOS DE ODOO:"
    echo "   - Para cada usuario que necesite manejar llamadas:"
    echo "     * Ve a Usuarios > [Seleccionar Usuario]"
    echo "     * En la pestaña 'Telefonía', configura la extensión correspondiente"
    echo ""
    echo "5. CONFIGURACIÓN DEL SOFTPHONE (PARA CADA USUARIO):"
    echo "   - Descarga un softphone como Zoiper, Linphone o MicroSIP"
    echo "   - Configura la cuenta SIP con estos datos:"
    echo "     * Servidor SIP: $EXTERNAL_IP"
    echo "     * Puerto: 5060"
    echo "     * Usuario: 1001 (administrador) o 1002 (usuario_prueba)"
    echo "     * Contraseña: clave_segura (para 1001) o password_user_1002 (para 1002)"
    echo ""
    echo "6. PROBANDO EL SISTEMA:"
    echo "   - Para probar una llamada interna:"
    echo "     * Desde el softphone con extensión 1001, marca 1002"
    echo "     * La llamada debería llegar al softphone con extensión 1002"
    echo ""
    echo "   - Para probar una llamada entrante de Zadarma:"
    echo "     * La llamada debería aparecer en el softphone con extensión 1001"
    echo ""
    echo "7. SOLUCIÓN DE PROBLEMAS:"
    echo "   - Verifica logs de Asterisk: tail -f /var/log/asterisk/full"
    echo "   - Comprueba estado Asterisk: asterisk -rvvv"
    echo "   - Verifica puertos abiertos: netstat -tuplan | grep asterisk"
    echo ""
    echo "===================================================================="
}

# Función para mostrar un resumen de configuración actual
show_config_summary() {
    echo ""
    echo "===================================================================="
    echo "               RESUMEN DE CONFIGURACIÓN ACTUAL                      "
    echo "===================================================================="
    echo ""
    echo "IP EXTERNA: $(get_external_ip)"
    echo ""
    echo "PUERTOS CONFIGURADOS:"
    echo " - SIP: 5060 (UDP/TCP)"
    echo " - AMI: 5038 (TCP)"
    echo " - Asterisk ARI: 8088 (TCP)"
    echo " - RTP: 10000-20000 (UDP)"
    echo ""
    echo "MÓDULOS ENCONTRADOS:"
    for module in "${REQUIRED_MODULES[@]}"; do
        if [ -d "$ODOO_ADDONS_DIR/$module" ]; then
            echo " - $module: ✓"
        else
            echo " - $module: ✗"
        fi
    done
    echo ""
    echo "USUARIOS CONFIGURADOS:"
    echo " - Extensión 1001: Administrador (admin)"
    echo " - Extensión 1002: Usuario Prueba (usuario_prueba)"
    echo " - Extensión 2000: Test Extension (test_extension)"
    echo ""
    echo "PROVEEDOR VOIP:"
    echo " - Servicio: Zadarma"
    echo " - Usuario: 908733"
    echo " - Servidor: sip.zadarma.com"
    echo ""
    echo "===================================================================="
}

# Función principal
main1() {
    echo "[+] Iniciando configuración del Call Center para Odoo con Asterisk..."
    
    # Crear directorio temporal si no existe
    mkdir -p $TEMP_DIR
    
    # Verificar módulos requeridos
    check_required_modules
    
    # Instalar dependencias del sistema
    install_system_dependencies
    
    # Configurar Asterisk
    configure_asterisk
    
    # Configurar permisos
   #set_permissions
    
    # Crear extensión SIP de prueba
    create_test_sip_extension
    
    # Test de conectividad
    test_asterisk_connectivity
    
    # Mostrar resumen de configuración
    show_config_summary
    
    # Mostrar instrucciones post-instalación
    post_install_instructions
    
    echo "[+] ¡Configuración del Call Center completada!"
}

# Ejecutar la función principal
main1

#--------------------------------------------------------
# Script unificado para configuración completa de Asterisk + Call Center Odoo
# Fusión de asterisk_complete_config.sh y call_center_module.sh
# Datos del usuario:
# - PBX: pbx.zadarma.com
# - Extension: 100 (Login: 508443-100)
# - Trunk: 908733 / 118bGuzuEt

set -e

# Detectar sistema operativo y limpiar pantalla
if [ "$OSTYPE" == "msys" ] || [ "$OSTYPE" == "win32" ]; then
    cls
else
    clear
fi

# Arte ASCII
art_ascii="
     ██████╗ ██████╗  ██████╗  ██████╗     ██████╗ █████╗ ██╗     ██╗         
    ██╔═══██╗██╔══██╗██╔═══██╗██╔═══██╗   ██╔════╝██╔══██╗██║     ██║         
    ██║   ██║██║  ██║██║   ██║██║   ██║   ██║     ███████║██║     ██║         
    ██║   ██║██║  ██║██║   ██║██║   ██║   ██║     ██╔══██║██║     ██║         
    ╚██████╔╝██████╔╝╚██████╔╝╚██████╔╝   ╚██████╗██║  ██║███████╗███████╗    
     ╚═════╝ ╚═════╝  ╚═════╝  ╚═════╝     ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝    
                                                                        
     ██████╗███████╗███╗   ██╗████████╗███████╗██████╗                         
    ██╔════╝██╔════╝████╗  ██║╚══██╔══╝██╔════╝██╔══██╗                        
    ██║     █████╗  ██╔██╗ ██║   ██║   █████╗  ██████╔╝                        
    ██║     ██╔══╝  ██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗                        
    ╚██████╗███████╗██║ ╚████║   ██║   ███████╗██║  ██║                        
     ╚═════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝                        
            ASTERISK + ODOO CALL CENTER                                                  
"

echo -e "$art_ascii\n"

# Comprobar si está ejecutando como root o con sudo
if [ "$EUID" -ne 0 ]; then
    echo "[!] Este script requiere privilegios de administrador"
    echo "[!] Por favor ejecute: sudo $0"
    exit 1
fi

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
ASTERISK_CONF_DIR="/etc/asterisk"
ODOO_ADDONS_DIR="external-addons"
MODULES=("asterisk_plus" "base_phone" "asterisk_click2dial")
TEMP_DIR="/tmp/odoo_call_center_modules"

echo -e "${GREEN}=== Configuración Completa de Asterisk + Call Center Odoo ===${NC}"

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
        EXTERNAL_IP="172.27.128.1"
        echo -e "${YELLOW}[!] No se pudo determinar la IP pública automáticamente.${NC}"
        echo -e "${YELLOW}[!] Usando IP por defecto: $EXTERNAL_IP${NC}"
    fi
    
    echo "$EXTERNAL_IP"
}

# Función para crear archivos de configuración
create_config_file() {
    local filename="$1"
    local content="$2"
    echo -e "${GREEN}[+] Creando $filename...${NC}"
    echo "$content" | sudo tee "$ASTERISK_CONF_DIR/$filename" > /dev/null
}

# Función para instalar dependencias necesarias
install_dependencies() {
    echo -e "${GREEN}[+] Instalando dependencias necesarias...${NC}"
    apt update
    apt install -y gdebi wget unzip python3-pip asterisk
    pip3 install gdown

    if [ $? -ne 0 ]; then
        echo -e "${RED}[-] Error instalando dependencias. Por favor verifica la conexión a internet.${NC}"
        exit 1
    fi
}

# CONFIGURACIÓN DE ASTERISK
configure_asterisk() {
    echo -e "${BLUE}=== CONFIGURANDO ASTERISK ===${NC}"
    
    # Obtener IP externa
    EXTERNAL_IP=$(get_external_ip)
    
    # 1. asterisk.conf - Configuración principal
    create_config_file "asterisk.conf" "[options]
verbose = 3
debug = 3
transmit_silence = yes
user_agent = Platform PBX

[directories]
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk"

    # 2. modules.conf - Módulos a cargar
    create_config_file "modules.conf" "[modules]
autoload = yes

; Core modules
load => res_pjsip.so
load => res_pjsip_authenticator_digest.so
load => res_pjsip_endpoint_identifier_user.so
load => res_pjsip_endpoint_identifier_ip.so
load => res_pjsip_outbound_registration.so
load => res_pjsip_registrar.so
load => res_pjsip_session.so

; PBX and applications
load => pbx_config.so
load => app_dial.so
load => app_echo.so
load => app_playback.so
load => app_voicemail.so
load => app_directory.so

; ARI modules for web interface
load => res_ari.so
load => res_ari_applications.so
load => res_ari_asterisk.so
load => res_ari_bridges.so
load => res_ari_channels.so
load => res_ari_device_states.so
load => res_ari_endpoints.so
load => res_ari_events.so
load => res_ari_playbacks.so
load => res_ari_recordings.so
load => res_ari_sounds.so
load => res_http_websocket.so
load => res_ari_websockets.so

; HTTP and Manager
load => res_http.so
load => app_http.so

; Music on hold
load => res_musiconhold.so

; CDR
load => cdr_csv.so

; Disable unnecessary modules
noload => chan_sip.so
noload => chan_iax2.so
noload => chan_mgcp.so
noload => chan_skinny.so
noload => pbx_ael.so
noload => pbx_lua.so"

    # 3. pjsip.conf - Configuración SIP principal
    create_config_file "pjsip.conf" "; ================================
; Transport Configuration
; ================================
[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5060
external_media_address = $EXTERNAL_IP
external_signaling_address = $EXTERNAL_IP

; ================================
; Zadarma Trunk Configuration
; ================================
[zadarma-auth]
type = auth
auth_type = userpass
username = 908733
password = 118bGuzuEt

[zadarma-aor]
type = aor
contact = sip:sip.zadarma.com:5060
qualify_frequency = 60
max_contacts = 1

[zadarma-endpoint]
type = endpoint
transport = transport-udp
context = from-zadarma
disallow = all
allow = ulaw,alaw,g722
outbound_auth = zadarma-auth
aors = zadarma-aor
identify_by = username
rtp_symmetric = yes
force_rport = yes
rewrite_contact = yes
send_rpid = yes
send_pai = yes

[zadarma-registration]
type = registration
outbound_auth = zadarma-auth
server_uri = sip:sip.zadarma.com:5060
client_uri = sip:908733@sip.zadarma.com
retry_interval = 60
max_retries = 0

[zadarma-identify]
type = identify
endpoint = zadarma-endpoint
match = sip.zadarma.com

; ================================
; VoIPVoIP Extension 100 Configuration
; ================================
[ext100-auth]
type = auth
auth_type = userpass
username = 508443-100
password = your_extension_password_here

[ext100-aor]
type = aor
max_contacts = 5
qualify_frequency = 60
default_expiration = 300

[ext100]
type = endpoint
transport = transport-udp
context = from-internal
disallow = all
allow = ulaw,alaw,g722
auth = ext100-auth
aors = ext100-aor
identify_by = username
rtp_symmetric = yes
force_rport = yes
rewrite_contact = yes
callerid = Extension 100 <100>
mailboxes = 100@default
set_var = TRUNK_ENDPOINT=zadarma-endpoint

; ================================
; Local Extensions (1001, 1002)
; ================================
[auth1001]
type = auth
auth_type = userpass
username = 1001
password = clave_segura

[1001]
type = aor
max_contacts = 5
qualify_frequency = 60

[1001]
type = endpoint
transport = transport-udp
context = from-internal
disallow = all
allow = ulaw,alaw,g722
auth = auth1001
aors = 1001
identify_by = username
rtp_symmetric = yes
force_rport = yes
rewrite_contact = yes
callerid = Administrator <1001>
mailboxes = 1001@default
set_var = TRUNK_ENDPOINT=zadarma-endpoint

[auth1002]
type = auth
auth_type = userpass
username = 1002
password = clave_segura2

[1002]
type = aor
max_contacts = 5
qualify_frequency = 60

[1002]
type = endpoint
transport = transport-udp
context = from-internal
disallow = all
allow = ulaw,alaw,g722
auth = auth1002
aors = 1002
identify_by = username
rtp_symmetric = yes
force_rport = yes
rewrite_contact = yes
callerid = Test User <1002>
mailboxes = 1002@default
set_var = TRUNK_ENDPOINT=zadarma-endpoint

; ================================
; Global Settings
; ================================
[global]
type = global
user_agent = Platform PBX
endpoint_identifier_order = ip,username,anonymous
max_forwards = 70
keep_alive_interval = 90"

    # 4. extensions.conf - Plan de marcado
    create_config_file "extensions.conf" "; ================================
; Extension Configuration for Platform PBX
; ================================

[general]
static = yes
writeprotect = no
clearglobalvars = no

[globals]
; Trunk configuration
TRUNK_ENDPOINT = zadarma-endpoint
COUNTRY_CODE = 34
DIAL_TIMEOUT = 30

; Voicemail settings
VOICEMAIL_RECGAINDB = 
VOICEMAIL_TEMPLATE = 

; ================================
; Internal Extensions Context
; ================================
[from-internal]
; Extension 100 (VoIPVoIP Extension)
exten => 100,1,NoOp(Call to Extension 100)
exten => 100,n,Set(CALLERID(name)=Extension 100)
exten => 100,n,Dial(PJSIP/ext100,\${GLOBAL(DIAL_TIMEOUT)})
exten => 100,n,Voicemail(100@default,u)
exten => 100,n,Hangup()

; Extension 1001 (Administrator)
exten => 1001,1,NoOp(Call to Administrator)
exten => 1001,n,Set(CALLERID(name)=Administrator)
exten => 1001,n,Dial(PJSIP/1001,\${GLOBAL(DIAL_TIMEOUT)})
exten => 1001,n,Voicemail(1001@default,u)
exten => 1001,n,Hangup()

; Extension 1002 (Test User)
exten => 1002,1,NoOp(Call to Test User)
exten => 1002,n,Set(CALLERID(name)=Test User)
exten => 1002,n,Dial(PJSIP/1002,\${GLOBAL(DIAL_TIMEOUT)})
exten => 1002,n,Voicemail(1002@default,u)
exten => 1002,n,Hangup()

; Echo test
exten => 600,1,Answer()
exten => 600,n,Echo()
exten => 600,n,Hangup()

; Voicemail access
exten => *97,1,VoiceMailMain(@default)
exten => *97,n,Hangup()

; External calls - National numbers (9 digits)
exten => _9XXXXXXXXX,1,NoOp(Outbound call to \${EXTEN:1})
exten => _9XXXXXXXXX,n,Set(CALLERID(num)=\${CALLERID(num)})
exten => _9XXXXXXXXX,n,Dial(PJSIP/\${EXTEN:1}@\${GLOBAL(TRUNK_ENDPOINT)},\${GLOBAL(DIAL_TIMEOUT)})
exten => _9XXXXXXXXX,n,Hangup()

; International calls (00 + country code + number)
exten => _900.,1,NoOp(International call to \${EXTEN:1})
exten => _900.,n,Set(CALLERID(num)=\${CALLERID(num)})
exten => _900.,n,Dial(PJSIP/\${EXTEN:1}@\${GLOBAL(TRUNK_ENDPOINT)},\${GLOBAL(DIAL_TIMEOUT)})
exten => _900.,n,Hangup()

; Mobile numbers (6XXXXXXXX, 7XXXXXXXX)
exten => _9[67]XXXXXXXX,1,NoOp(Mobile call to \${EXTEN:1})
exten => _9[67]XXXXXXXX,n,Set(CALLERID(num)=\${CALLERID(num)})
exten => _9[67]XXXXXXXX,n,Dial(PJSIP/\${EXTEN:1}@\${GLOBAL(TRUNK_ENDPOINT)},\${GLOBAL(DIAL_TIMEOUT)})
exten => _9[67]XXXXXXXX,n,Hangup()

; ================================
; Incoming calls from Zadarma
; ================================
[from-zadarma]
; Route incoming calls to extension 100
exten => _X.,1,NoOp(Incoming call from Zadarma: \${CALLERID(all)})
exten => _X.,n,Set(CDR(accountcode)=zadarma-in)
exten => _X.,n,Goto(from-internal,100,1)

; Direct DID routing if needed
exten => 508443,1,NoOp(Direct DID call)
exten => 508443,n,Goto(from-internal,100,1)

; ================================
; Context for external routing
; ================================
[outbound-routes]
; This context can be used for complex outbound routing

; ================================
; Emergency and special numbers
; ================================
[emergency]
exten => 112,1,NoOp(Emergency call)
exten => 112,n,Dial(PJSIP/112@\${GLOBAL(TRUNK_ENDPOINT)})
exten => 112,n,Hangup()

; Include emergency in internal context
[from-internal](+)
include => emergency"

    # Configuraciones adicionales (HTTP, ARI, Manager, etc.)
    create_config_file "http.conf" "[general]
enabled = yes
bindaddr = 0.0.0.0
bindport = 8088
enablestatic = yes
redirect = / /static/config/index.html

[post_mappings]"

    create_config_file "ari.conf" "[general]
enabled = yes
pretty = yes
allowed_origins = *

[admin]
type = user
read_only = no
password = admin"

    create_config_file "manager.conf" "[general]
enabled = yes
port = 5038
bindaddr = 0.0.0.0
timestampevents = yes

[admin]
secret = admin
read = all
write = all"

    create_config_file "voicemail.conf" "[general]
format = wav49|gsm|wav
serveremail = asterisk@localhost
attach = yes
skipms = 3000
maxsilence = 10
silencethreshold = 128
maxlogins = 3
emaildateformat = %A, %B %d, %Y at %r
emailsubject = [PBX]: New message \${VM_MSGNUM} in mailbox \${VM_MAILBOX}
emailbody = Dear \${VM_NAME}:\n\n\tjust wanted to let you know you were sent a new voice message\n\n\tOriginal message saved in: \${VM_MESSAGEFILE}\n\n\t\t\t\t--Asterisk\n

[zonemessages]
eastern = America/New_York|'vm-received' Q 'digits/at' IMp
central = America/Chicago|'vm-received' Q 'digits/at' IMp
mountain = America/Denver|'vm-received' Q 'digits/at' IMp
pacific = America/Los_Angeles|'vm-received' Q 'digits/at' IMp
european = Europe/Copenhagen|'vm-received' a d b 'digits/at' HM

[default]
100 => 1234,Extension 100,admin@localhost
1001 => 1234,Administrator,admin@localhost
1002 => 1234,Test User,user@localhost"

    create_config_file "rtp.conf" "[general]
rtpstart = 10000
rtpend = 20000
strictrtp = yes
probation = 4
icesupport = yes
stunaddr = stun.l.google.com:19302"

    # Crear directorios necesarios y configurar permisos
    echo -e "${GREEN}[+] Creando directorios necesarios...${NC}"
    sudo mkdir -p /var/lib/asterisk/moh
    sudo mkdir -p /var/lib/asterisk/sounds
    sudo mkdir -p /var/log/asterisk
    sudo mkdir -p /var/spool/asterisk/voicemail/default

    echo -e "${GREEN}[+] Configurando permisos...${NC}"
    sudo chown -R asterisk:asterisk /var/lib/asterisk
    sudo chown -R asterisk:asterisk /var/log/asterisk
    sudo chown -R asterisk:asterisk /var/spool/asterisk
    sudo chown -R asterisk:asterisk /etc/asterisk
}

# CONFIGURACIÓN DE ODOO CALL CENTER
configure_odoo_call_center() {
    echo -e "${BLUE}=== CONFIGURANDO ODOO CALL CENTER ===${NC}"
    
    # Comprobar si existe la carpeta de addons de Odoo
    if [ ! -d "$ODOO_ADDONS_DIR" ]; then
        echo -e "${YELLOW}[!] No se encuentra la carpeta $ODOO_ADDONS_DIR${NC}"
        echo -e "${YELLOW}[!] Creando estructura de directorios...${NC}"
        mkdir -p "$ODOO_ADDONS_DIR"
    fi
    
    echo -e "${GREEN}[+] Configurando módulos de Call Center...${NC}"
    
    # Crear estructura básica para los módulos (placeholder)
    for MODULE in "${MODULES[@]}"; do
        if [ ! -d "$ODOO_ADDONS_DIR/$MODULE" ]; then
            echo -e "${YELLOW}[+] Creando estructura para módulo $MODULE${NC}"
            mkdir -p "$ODOO_ADDONS_DIR/$MODULE"
            
            # Crear manifest básico
            cat > "$ODOO_ADDONS_DIR/$MODULE/__manifest__.py" << EOF
{
    'name': '$MODULE',
    'version': '1.0.0',
    'category': 'Phone',
    'summary': 'Call Center Integration Module',
    'description': 'Module for Asterisk integration with Odoo',
    'depends': ['base'],
    'data': [],
    'installable': True,
    'auto_install': False,
}
EOF
            
            # Crear __init__.py vacío
            touch "$ODOO_ADDONS_DIR/$MODULE/__init__.py"
        fi
    done
}

# Función para instalar las dependencias de Python necesarias para los módulos
install_python_dependencies() {
    echo -e "${GREEN}[+] Instalando dependencias de Python para los módulos...${NC}"
    
    # Dependencias para los módulos Asterisk
    if command -v docker &> /dev/null; then
        docker exec odoo pip3 install phonenumbers py-Asterisk 2>/dev/null || {
            echo -e "${YELLOW}[!] No se pudo conectar al contenedor Odoo${NC}"
            echo -e "${YELLOW}[!] Instalando dependencias en el sistema local...${NC}"
            pip3 install phonenumbers py-Asterisk
        }
    else
        pip3 install phonenumbers py-Asterisk
    fi
}

# Función para configurar permisos adecuados para los módulos
set_permissions() {
    echo -e "${GREEN}[+] Configurando permisos para los módulos...${NC}"
    chmod -R 755 "$ODOO_ADDONS_DIR"
    if id "odoo" &>/dev/null; then
        chown -R odoo:odoo "$ODOO_ADDONS_DIR"
    else
        chown -R 1000:1000 "$ODOO_ADDONS_DIR"  # UID:GID típico para el usuario odoo en el contenedor
    fi
}

# Función para reiniciar servicios
restart_services() {
    echo -e "${GREEN}[+] Reiniciando servicios...${NC}"
    
    # Reiniciar Asterisk
    echo -e "${GREEN}[+] Reiniciando Asterisk...${NC}"
    sudo systemctl restart asterisk
    sleep 5
    
    # Reiniciar contenedores de Odoo si existen
    if command -v docker-compose &> /dev/null && [ -f "docker-compose.yml" ]; then
        echo -e "${GREEN}[+] Reiniciando contenedores Odoo...${NC}"
        docker-compose down
        docker-compose up -d
    fi
}

# Función para verificar estado de servicios
verify_services() {
    echo -e "${GREEN}[+] Verificando estado de servicios...${NC}"
    
    # Verificar Asterisk
    if sudo systemctl is-active --quiet asterisk; then
        echo -e "${GREEN}✓ Asterisk está ejecutándose correctamente${NC}"
    else
        echo -e "${RED}✗ Error: Asterisk no está ejecutándose${NC}"
        echo -e "${YELLOW}Revisando logs...${NC}"
        sudo journalctl -u asterisk --no-pager -l -n 10
    fi
    
    # Verificar contenedores Docker
    if command -v docker &> /dev/null; then
        if docker ps | grep -q "odoo"; then
            echo -e "${GREEN}✓ Contenedor Odoo está ejecutándose${NC}"
        else
            echo -e "${YELLOW}! Contenedor Odoo no encontrado o no está ejecutándose${NC}"
        fi
    fi
}

# Función para proporcionar instrucciones después de la instalación
post_install_instructions() {
    EXTERNAL_IP=$(get_external_ip)
    echo ""
    echo -e "${GREEN}==================================================================="
    echo -e "            CONFIGURACIÓN COMPLETADA - INSTRUCCIONES FINALES"
    echo -e "===================================================================${NC}"
    echo ""
    echo -e "${YELLOW}ASTERISK CONFIGURADO:${NC}"
    echo -e "  ✓ Servidor Asterisk configurado en puerto 5060"
    echo -e "  ✓ ARI habilitado en puerto 8088 (usuario: admin, password: admin)"
    echo -e "  ✓ AMI habilitado en puerto 5038 (usuario: admin, password: admin)"
    echo ""
    echo -e "${YELLOW}EXTENSIONES CONFIGURADAS:${NC}"
    echo -e "  • 100 (VoIPVoIP Extension): Usuario: 508443-100"
    echo -e "  • 1001 (Administrator): Usuario: 1001, Password: clave_segura"
    echo -e "  • 1002 (Test User): Usuario: 1002, Password: clave_segura2"
    echo ""
    echo -e "${YELLOW}TRUNK ZADARMA:${NC}"
    echo -e "  • Trunk: 908733 / 118bGuzuEt"
    echo -e "  • Servidor: sip.zadarma.com:5060"
    echo ""
    echo -e "${YELLOW}ODOO CALL CENTER:${NC}"
    echo -e "  1. Accede a Odoo en http://$EXTERNAL_IP:8069"
    echo -e "  2. Ve a Aplicaciones y busca e instala los siguientes módulos:"
    echo -e "     - asterisk_plus"
    echo -e "     - base_phone"
    echo -e "     - asterisk_click2dial"
    echo ""
    echo -e "  3. Configura la integración con Asterisk en Odoo:"
    echo -e "     - Ve a Ajustes > Técnico > Asterisk Servers"
    echo -e "     - Configura el servidor con estos datos:"
    echo -e "       * Nombre: Asterisk PBX"
    echo -e "       * Host: $EXTERNAL_IP"
    echo -e "       * Puerto ARI: 8088"
    echo -e "       * Usuario ARI: admin"
    echo -e "       * Contraseña ARI: admin"
    echo ""
    echo -e "${YELLOW}NÚMEROS DE PRUEBA:${NC}"
    echo -e "  - 600: Echo test"
    echo -e "  - *97: Acceso a buzón de voz"
    echo ""
    echo -e "${YELLOW}LLAMADAS SALIENTES:${NC}"
    echo -e "  - 9 + número nacional (ej: 9612345678)"
    echo -e "  - 900 + número internacional (ej: 900441234567890)"
    echo ""
    echo -e "${RED}IMPORTANTE:${NC}"
    echo -e "  - Configura la contraseña de la extensión 100 en /etc/asterisk/pjsip.conf"
    echo -e "  - Verifica que la IP externa ($EXTERNAL_IP) sea correcta"
    echo -e "  - Los puertos 5060, 8088, 5038 y 10000-20000 deben estar abiertos"
    echo ""
    echo -e "${GREEN}==================================================================="
    echo -e "                        ¡INSTALACIÓN COMPLETADA!"  
    echo -e "===================================================================${NC}"
}

# Función principal
main2() {
    echo -e "${GREEN}[+] Iniciando configuración unificada de Asterisk + Call Center Odoo...${NC}"
    
    # Instalar dependencias necesarias
    install_dependencies
    
    # Configurar Asterisk
    configure_asterisk
    
    # Configurar módulos de Odoo Call Center
    configure_odoo_call_center
    
    # Instalar dependencias de Python
    install_python_dependencies
    
    # Configurar permisos
    set_permissions
    
    # Reiniciar servicios
    restart_services
    
    # Verificar estado de servicios
    verify_services
    
    # Mostrar instrucciones post-instalación
    post_install_instructions
}

# Ejecutar función principal
main2