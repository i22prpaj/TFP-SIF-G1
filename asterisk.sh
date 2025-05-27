#!/bin/bash

# Script optimizado para configuración específica de Asterisk con Zadarma
# Complementa al script principal call-center-modules+complete+copy.sh
# Se enfoca solo en configuraciones específicas no cubiertas por el script principal

set -e

# Detectar sistema operativo y limpiar pantalla
if [ "$OSTYPE" == "msys" ] || [ "$OSTYPE" == "win32" ]; then
    cls
else
    clear
fi

# Arte ASCII simplificado
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

                    Asterisk Dependencies
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

# Variables específicas
ASTERISK_CONF_DIR="/etc/asterisk"
WORKING_DIR=$(pwd)

# Verificar que el script principal ya se haya ejecutado
check_main_script_execution() {
    echo -e "${YELLOW}[+] Verificando configuración previa...${NC}"
    
    if [ ! -f "$ASTERISK_CONF_DIR/pjsip.conf" ] || [ ! -f "$ASTERISK_CONF_DIR/extensions.conf" ]; then
        echo -e "${RED}[!] No se encontraron archivos de configuración básicos${NC}"
        echo -e "${RED}[!] Por favor ejecute primero: call-center-modules+complete+copy.sh${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[✓] Configuración básica encontrada${NC}"
}

# Obtener IP externa optimizada
get_external_ip() {
    # Intentar múltiples métodos para obtener IP externa
    local ip=""
    
    # Método 1: GCP metadata service
    ip=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || echo "")
    
    # Método 2: Servicios públicos
    if [ -z "$ip" ]; then
        ip=$(curl -s --connect-timeout 5 https://api.ipify.org 2>/dev/null || echo "")
    fi
    
    if [ -z "$ip" ]; then
        ip=$(curl -s --connect-timeout 5 http://checkip.amazonaws.com 2>/dev/null || echo "")
    fi
    
    # Fallback: IP local
    if [ -z "$ip" ]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    
    echo "$ip"
}

# Optimización específica de Asterisk
optimize_asterisk_performance() {
    echo -e "${BLUE}[+] Optimizando rendimiento de Asterisk...${NC}"
    
    # Crear configuración optimizada para logger.conf
    cat > "$ASTERISK_CONF_DIR/logger.conf" << 'EOF'
[general]
dateformat = %F %T.%3q

[logfiles]
console => notice,warning,error,debug,verbose
messages => notice,warning,error
full => notice,warning,error,debug,verbose
syslog.local0 => notice,warning,error
EOF

    # Configuración de CDR optimizada
    cat > "$ASTERISK_CONF_DIR/cdr.conf" << 'EOF'
[general]
enable = yes
unanswered = yes
congestion = yes
endbeforehexten = yes
initiatedseconds = yes
batch = no
size = 100
time = 300
EOF

    # Configuración de música en espera
    cat > "$ASTERISK_CONF_DIR/musiconhold.conf" << 'EOF'
[default]
mode = files
directory = /var/lib/asterisk/moh
random = yes
EOF

    echo -e "${GREEN}[✓] Optimizaciones aplicadas${NC}"
}

# Configurar firewall específico para Asterisk
configure_asterisk_firewall() {
    echo -e "${BLUE}[+] Configurando reglas de firewall para Asterisk...${NC}"
    
    # Verificar si ufw está instalado
    if command -v ufw &> /dev/null; then
        # Permitir puertos SIP y RTP
        ufw allow 5060/udp comment "Asterisk SIP"
        ufw allow 5038/tcp comment "Asterisk AMI"
        ufw allow 8088/tcp comment "Asterisk ARI/HTTP"
        ufw allow 10000:20000/udp comment "Asterisk RTP"
        
        echo -e "${GREEN}[✓] Reglas UFW configuradas${NC}"
    elif command -v iptables &> /dev/null; then
        # Configurar iptables si UFW no está disponible
        iptables -A INPUT -p udp --dport 5060 -j ACCEPT
        iptables -A INPUT -p tcp --dport 5038 -j ACCEPT
        iptables -A INPUT -p tcp --dport 8088 -j ACCEPT
        iptables -A INPUT -p udp --dport 10000:20000 -j ACCEPT
        
        echo -e "${GREEN}[✓] Reglas iptables configuradas${NC}"
    else
        echo -e "${YELLOW}[!] No se encontró firewall configurado${NC}"
    fi
}

# Test avanzado de conectividad Asterisk
advanced_asterisk_connectivity_test() {
    echo -e "${BLUE}[+] Realizando tests avanzados de conectividad...${NC}"
    
    # Test 1: AMI connectivity
    echo -e "${YELLOW}[+] Testeando AMI (puerto 5038)...${NC}"
    if timeout 5 bash -c "</dev/tcp/localhost/5038" 2>/dev/null; then
        echo -e "${GREEN}[✓] AMI accesible${NC}"
    else
        echo -e "${RED}[✗] AMI no accesible${NC}"
    fi
    
    # Test 2: ARI/HTTP connectivity
    echo -e "${YELLOW}[+] Testeando ARI/HTTP (puerto 8088)...${NC}"
    if timeout 5 bash -c "</dev/tcp/localhost/8088" 2>/dev/null; then
        echo -e "${GREEN}[✓] ARI/HTTP accesible${NC}"
    else
        echo -e "${RED}[✗] ARI/HTTP no accesible${NC}"
    fi
    
    # Test 3: SIP registration
    echo -e "${YELLOW}[+] Verificando registro SIP con Zadarma...${NC}"
    if asterisk -rx "pjsip show registrations" | grep -q "zadarma"; then
        echo -e "${GREEN}[✓] Registro SIP activo${NC}"
    else
        echo -e "${YELLOW}[!] Registro SIP no detectado${NC}"
    fi
    
    # Test 4: Endpoints status
    echo -e "${YELLOW}[+] Verificando estado de endpoints...${NC}"
    asterisk -rx "pjsip show endpoints" | grep -E "(1001|1002|ext100|zadarma)" || echo -e "${YELLOW}[!] Algunos endpoints no están registrados${NC}"
}

# Generar archivo de configuración específico para Odoo
generate_odoo_asterisk_config() {
    echo -e "${BLUE}[+] Generando configuración específica para Odoo...${NC}"
    
    EXTERNAL_IP=$(get_external_ip)
    
    # Crear archivo de configuración para Odoo
    cat > "$WORKING_DIR/odoo_asterisk_config.txt" << EOF
# Configuración para Asterisk Server en Odoo
# Vaya a: Configuración > Técnico > Asterisk Servers

DATOS DE CONEXIÓN:
- Nombre: Asterisk Platform PBX
- IP/DNS: $EXTERNAL_IP
- Puerto AMI: 5038
- Usuario AMI: admin
- Contraseña AMI: admin
- Puerto ARI: 8088
- Usuario ARI: admin
- Contraseña ARI: admin

CONFIGURACIÓN DE USUARIOS:
1. Usuario administrador:
   - Login Odoo: admin
   - Extensión: 1001
   - Contraseña SIP: clave_segura

2. Usuario prueba:
   - Login Odoo: usuario_prueba
   - Extensión: 1002
   - Contraseña SIP: clave_segura2

3. Usuario VoIPVoIP:
   - Login Odoo: voipvoip_user
   - Extensión: 100
   - Usuario SIP: 508443-100
   - Contraseña SIP: [configurar en pjsip.conf]

CONFIGURACIÓN DE SOFTPHONE:
- Servidor SIP: $EXTERNAL_IP:5060
- Protocolo: UDP
- Codecs: ulaw, alaw, g722

NÚMEROS DE PRUEBA:
- 600: Echo test
- *97: Acceso a buzón de voz
- 9 + número: Llamadas salientes

TRUNK CONFIGURADO:
- Proveedor: Zadarma
- Usuario: 908733
- Servidor: sip.zadarma.com:5060
EOF

    echo -e "${GREEN}[✓] Archivo de configuración creado: odoo_asterisk_config.txt${NC}"
}

# Crear script de diagnóstico
create_diagnostic_script() {
    echo -e "${BLUE}[+] Creando script de diagnóstico...${NC}"
    
    cat > "$WORKING_DIR/asterisk_diagnostics.sh" << 'EOF'
#!/bin/bash

echo "=== DIAGNÓSTICO ASTERISK ==="
echo "Timestamp: $(date)"
echo ""

echo "1. ESTADO DEL SERVICIO:"
systemctl status asterisk --no-pager -l

echo ""
echo "2. PUERTOS EN USO:"
netstat -tuln | grep -E ":(5060|5038|8088)"

echo ""
echo "3. REGISTROS SIP:"
asterisk -rx "pjsip show registrations"

echo ""
echo "4. ENDPOINTS:"
asterisk -rx "pjsip show endpoints"

echo ""
echo "5. CANALES ACTIVOS:"
asterisk -rx "core show channels"

echo ""
echo "6. ÚLTIMOS LOGS (últimas 10 líneas):"
tail -n 10 /var/log/asterisk/full

echo ""
echo "7. MEMORIA Y CPU:"
ps aux | grep asterisk | grep -v grep

echo ""
echo "=== FIN DIAGNÓSTICO ==="
EOF

    chmod +x "$WORKING_DIR/asterisk_diagnostics.sh"
    echo -e "${GREEN}[✓] Script de diagnóstico creado: asterisk_diagnostics.sh${NC}"
}

# Verificar módulos de Odoo específicos
verify_odoo_modules() {
    echo -e "${BLUE}[+] Verificando módulos de Odoo Call Center...${NC}"
    
    local modules_dir="external-addons"
    local required_modules=("asterisk_plus" "base_phone" "asterisk_click2dial")
    
    if [ ! -d "$modules_dir" ]; then
        echo -e "${YELLOW}[!] Directorio $modules_dir no encontrado${NC}"
        return 1
    fi
    
    for module in "${required_modules[@]}"; do
        if [ -d "$modules_dir/$module" ]; then
            echo -e "${GREEN}[✓] Módulo $module encontrado${NC}"
        else
            echo -e "${YELLOW}[!] Módulo $module no encontrado${NC}"
        fi
    done
}

# Configurar logs rotativos para Asterisk
configure_log_rotation() {
    echo -e "${BLUE}[+] Configurando rotación de logs...${NC}"
    
    cat > "/etc/logrotate.d/asterisk" << 'EOF'
/var/log/asterisk/full
/var/log/asterisk/messages
/var/log/asterisk/error {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 0644 asterisk asterisk
    postrotate
        /usr/sbin/asterisk -rx 'logger rotate' > /dev/null 2>&1 || true
    endscript
}
EOF

    echo -e "${GREEN}[✓] Rotación de logs configurada${NC}"
}

# Función principal optimizada
main1() {
    echo -e "${GREEN}[+] Iniciando optimización específica de Asterisk...${NC}"
    
    # Verificar que el script principal ya se ejecutó
    check_main_script_execution
    
    # Optimizaciones específicas
    optimize_asterisk_performance
    configure_asterisk_firewall
    configure_log_rotation
    
    # Tests y diagnósticos
    advanced_asterisk_connectivity_test
    
    # Generar archivos de ayuda
    generate_odoo_asterisk_config
    create_diagnostic_script
    
    # Verificaciones adicionales
    verify_odoo_modules
    
    echo ""
    echo -e "${GREEN}=================================================================="
    echo -e "           OPTIMIZACIÓN DE ASTERISK COMPLETADA"
    echo -e "==================================================================${NC}"
    echo ""
    echo -e "${YELLOW}ARCHIVOS GENERADOS:${NC}"
    echo -e "  ✓ odoo_asterisk_config.txt - Configuración para Odoo"
    echo -e "  ✓ asterisk_diagnostics.sh - Script de diagnóstico"
    echo ""
    echo -e "${YELLOW}OPTIMIZACIONES APLICADAS:${NC}"
    echo -e "  ✓ Configuración de logs optimizada"
    echo -e "  ✓ Rotación automática de logs"
    echo -e "  ✓ Reglas de firewall configuradas"
    echo -e "  ✓ Tests de conectividad realizados"
    echo ""
    echo -e "${YELLOW}PARA DIAGNÓSTICO:${NC}"
    echo -e "  Ejecute: ./asterisk_diagnostics.sh"
    echo ""
    echo -e "${GREEN}¡Optimización completada exitosamente!${NC}"
}

# Ejecutar función principal
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
                          
        ASTERISK + ODOO CALL CENTER - COMPLETE CONFIGURATION                                        
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