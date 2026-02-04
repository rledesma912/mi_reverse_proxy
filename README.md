# Proxy Inverso Local con Nginx, Docker y SSL Automático

Este proyecto proporciona una configuración de proxy inverso lista para usar con Docker y Nginx, diseñada para el desarrollo local. Permite gestionar múltiples sitios web locales bajo dominios personalizados (ej. `proyecto.local`) con HTTPS habilitado automáticamente a través de certificados autofirmados.

La principal ventaja es un script que genera automáticamente los certificados SSL necesarios basándose en la configuración de Nginx, simplificando enormemente la gestión de nuevos sitios.

## Características

- **Gestión de Múltiples Dominios**: Sirve varios proyectos locales desde un único punto de entrada.
- **HTTPS Automático**: Configuración SSL lista para usar en un entorno de desarrollo.
- **Generación Automatizada de Certificados**: Un script (`generate_certs.sh`) detecta los dominios de tu configuración de Nginx y crea los certificados por ti.
- **Basado en Docker**: Entorno encapsulado y reproducible.

## Requisitos

- Docker
- Docker Compose
- `openssl` (para la ejecución del script de generación de certificados).

## Configuración Inicial

1.  **Clonar el Repositorio** (si aún no lo has hecho).

2.  **Crear el Archivo de Entorno**:
    Copia el archivo de ejemplo para crear tu configuración local. Este archivo define dónde se guardarán los certificados generados.
    ```bash
    cp .env.example .env
    ```

3.  **Generar los Certificados Iniciales**:
    El script leerá los dominios ya definidos en `nginx_config/default.conf` y creará sus certificados.
    ```bash
    bash generate_certs.sh
    ```
    > **Nota**: Si el script no es ejecutable, dale permisos con `chmod +x generate_certs.sh`.

## Flujo de Trabajo: Añadir un Nuevo Sitio Local

Este es el proceso que seguirás cada vez que quieras añadir un nuevo proyecto a tu proxy inverso.

1.  **Editar la Configuración de Nginx**:
    Abre `nginx_config/default.conf` y añade un nuevo bloque `server` para tu nuevo sitio. Asegúrate de que las directivas `ssl_certificate` y `ssl_certificate_key` sigan el patrón de nombrado esperado.

    *Ejemplo para un nuevo sitio `mi-proyecto.local`:*
    ```nginx
    server {
        listen 443 ssl http2;
        server_name mi-proyecto.local;

        ssl_certificate     /etc/nginx/certs/mi-proyecto.local.pem;
        ssl_certificate_key /etc/nginx/certs/mi-proyecto.local-key.pem;

        location / {
            # Apunta al puerto donde se ejecuta tu aplicación
            proxy_pass http://host.docker.internal:3000;
            proxy_set_header Host $host;
            # ... otras directivas de proxy ...
        }
    }
    ```

2.  **Editar el Archivo `hosts`**:
    Añade tu nuevo dominio al archivo `/etc/hosts` de tu sistema para que tu navegador sepa que debe apuntar a tu máquina local (`127.0.0.1`).

    ```bash
    # Abre el archivo con permisos de administrador
    sudo nano /etc/hosts
    ```

    Añade la nueva línea:
    ```
    127.0.0.1 mi-proyecto.local
    ```

3.  **Generar el Nuevo Certificado**:
    Simplemente vuelve a ejecutar el script. Detectará el nuevo dominio y generará únicamente el certificado que falta.
    ```bash
    ./generate_certs.sh
    ```

4.  **Reiniciar el Proxy Inverso**:
    Para que Nginx cargue la nueva configuración y el nuevo certificado, reinicia los contenedores.
    ```bash
    docker-compose up -d --force-recreate
    ```

¡Listo! Tu nuevo sitio ya es accesible en `https://mi-proyecto.local`.

## Uso Diario

-   **Iniciar el proxy inverso**:
    ```bash
    docker-compose up -d
    ```
-   **Detener el proxy inverso**:
    ```bash
    docker-compose down
    ```

## (Avanzado) Inicio Automático en el Arranque (Linux con systemd)

Para que el proxy inverso se inicie automáticamente al arrancar tu sistema (probado en Kubuntu/Ubuntu), puedes crear un servicio de `systemd`.

1.  **Crea el archivo del servicio**:
    ```bash
    sudo nano /etc/systemd/system/reverse-proxy.service
    ```

2.  **Pega el siguiente contenido**:
    Asegúrate de que `WorkingDirectory` apunte a la ruta absoluta de tu proyecto.

    ```ini
    [Unit]
    Description=Reverse Proxy with Docker Compose
    Requires=docker.service
    After=docker.service network-online.target

    [Service]
    Type=oneshot
    RemainAfterExit=true
    WorkingDirectory=/mnt/LLM/apps/reverse_proxy
    ExecStart=/usr/bin/docker-compose up -d
    ExecStop=/usr/bin/docker-compose down
    User=root

    [Install]
    WantedBy=multi-user.target
    ```

3.  **Habilita y arranca el servicio**:
    Estos comandos le dirán a `systemd` que reconozca el nuevo servicio, lo habilite para el arranque y lo inicie inmediatamente.
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable reverse-proxy.service
    sudo systemctl start reverse-proxy.service
    ```

4.  **Verifica el estado** (opcional):
    ```bash
    sudo systemctl status reverse-proxy.service
    ```
