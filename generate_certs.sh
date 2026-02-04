#!/bin/bash
#
# Este script genera certificados SSL autofirmados para los dominios
# definidos en la configuración de Nginx.

# --- Configuración y Comprobaciones Iniciales ---

# Salir inmediatamente si un comando falla
set -e

# Comprobar si openssl está instalado
if ! command -v openssl &> /dev/null; then
    echo "Error: openssl no está instalado. Por favor, instálalo para continuar."
    exit 1
fi

# Comprobar si el archivo .env existe
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: El archivo .env no se encuentra."
    echo "Por favor, copia .env.example a .env y configúralo si es necesario."
    exit 1
fi

# Cargar variables de entorno desde .env
export $(grep -v '^#' "$ENV_FILE" | xargs)

# Comprobar si la variable CERTS_DIR está definida
if [ -z "${CERTS_DIR}" ]; then
    echo "Error: La variable CERTS_DIR no está definida en el archivo .env."
    exit 1
fi

# --- Lógica Principal ---

NGINX_CONF_PATH="./nginx_config/default.conf"
echo "Usando el directorio de certificados: $CERTS_DIR"

# Crear el directorio de certificados si no existe
mkdir -p "$CERTS_DIR"
echo "Directorio de certificados asegurado."

# Extraer los nombres de servidor (dominios) de la configuración de Nginx
# - Busca líneas que contienen "server_name"
# - Excluye las que están comentadas (#)
# - Elimina "server_name" y el punto y coma final
# - Divide los nombres de servidor en líneas separadas
DOMAINS=$(grep "server_name" "$NGINX_CONF_PATH" | grep -v "#" | sed 's/server_name//g; s/;//g' | xargs -n 1)

if [ -z "$DOMAINS" ]; then
    echo "No se encontraron dominios en $NGINX_CONF_PATH. No se generaron certificados."
    exit 0
fi

echo "Dominios encontrados: $DOMAINS"

# Generar un certificado para cada dominio
for DOMAIN in $DOMAINS; do
    echo "--- Generando certificado para $DOMAIN ---"
    KEY_FILE="$CERTS_DIR/${DOMAIN}-key.pem"
    CERT_FILE="$CERTS_DIR/${DOMAIN}.pem"

    if [ -f "$CERT_FILE" ]; then
        echo "El certificado para $DOMAIN ya existe. Saltando."
    else
        openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
          -keyout "$KEY_FILE" \
          -out "$CERT_FILE" \
          -subj "/CN=$DOMAIN" \
          -addext "subjectAltName=DNS:$DOMAIN"
        echo "Certificado y clave para $DOMAIN creados en $CERTS_DIR"
    fi
done

echo "--- Proceso completado ---"
