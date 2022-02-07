#! /bin/sh

update_cert() {
    nginx -s reload
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S')][DataJoint]: Certs updated."
}

if [ ! -z "$SUBDOMAINS" ]; then 
    export SUBDOMAINS=${SUBDOMAINS}.
fi

cp /nginx.conf /etc/nginx/nginx.conf

env | grep ADD | sort | while IFS= read -r line; do
    TEMP_VAR=$(echo $line | cut -d'=' -f1)
    TEMP_VALUE=$(echo $line | cut -d'=' -f2)
    if echo $TEMP_VAR | grep ENDPOINT; then 
        TEMP_ENDPOINT=$TEMP_VALUE
    elif echo $TEMP_VAR | grep TARGET_PREFIX; then
        TEMP_TARGET_PREFIX=$TEMP_VALUE
    elif echo $TEMP_VAR | grep PREFIX; then 
        TEMP_PREFIX=$TEMP_VALUE
    elif echo $TEMP_VAR | grep PORT; then 
        TEMP_PORT=$TEMP_VALUE
    elif echo $TEMP_VAR | grep TYPE; then 
        TEMP_TYPE=$TEMP_VALUE
        if [ "$TEMP_PREFIX" = "/" ]; then
            TEMP_PREFIX=""
        fi
        service=$(echo $TEMP_ENDPOINT | cut -d':' -f1)
        port=$(echo $TEMP_ENDPOINT | cut -d':' -f2)
        if [ ! -z "$TEMP_PORT" ] && [ ! "$TEMP_PORT" = "" ]; then
            port=$TEMP_PORT
        fi
        if [ ! -f "/etc/nginx/conf.d/port_${port}.conf" ] && [ ! "$TEMP_TYPE" = "DATABASE" ] && [ ! "$TEMP_TYPE" = "STATIC" ]; then
            cp /http.conf /etc/nginx/conf.d/port_${port}.conf
            if [ ! -f "/etc/nginx/conf.d/port_443.conf" ]; then
                cp /https.conf /etc/nginx/conf.d/port_443.conf
            fi
        fi

        echo 
        echo "TEMP_TYPE=${TEMP_TYPE}"
        echo 
        echo "TEMP_ENDPOINT=${TEMP_ENDPOINT}"

        if [ "$TEMP_TYPE" = "MINIO" ] && [ "$TEMP_PREFIX" = "" ]; then
            REPLACE='$ i\
  location / {\
    client_max_body_size 0;\
    proxy_buffering off;\
    #access_log off;\
    proxy_http_version 1.1;\
    proxy_set_header Host $http_host;\
    proxy_pass http://'${TEMP_ENDPOINT}'/;\
  }\
'
            sed -i "$REPLACE" /etc/nginx/conf.d/port_${port}.conf
            sed -i "$REPLACE" /etc/nginx/conf.d/port_443.conf
        elif [ "$TEMP_TYPE" = "MINIO" ]; then
            TEMP_PREFIX=$(echo $TEMP_PREFIX | sed -e "s|\.|\\\\\\\.|g")
            REPLACE='$ i\
  location ~ ^'${TEMP_PREFIX}'\\.(?:[a-z0-9]+[.\\-])*[a-z0-9]+(\\?.*|\\/.*)?$ {\
    client_max_body_size 0;\
    proxy_buffering off;\
    #access_log off;\
    proxy_set_header X-Real-IP $remote_addr;\
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
    proxy_set_header X-Forwarded-Proto $scheme;\
    proxy_set_header Host $http_host;\
    proxy_connect_timeout 300;\
    proxy_http_version 1.1;\
    proxy_set_header Connection "";\
    chunked_transfer_encoding off;\
    proxy_pass http://'${TEMP_ENDPOINT}';\
  }\
'
            sed -i "$REPLACE" /etc/nginx/conf.d/port_${port}.conf
            sed -i "$REPLACE" /etc/nginx/conf.d/port_443.conf
        elif [ "$TEMP_TYPE" = "MINIOADMIN" ]; then
            REPLACE='$ i\
  location ~ ^/minio/?(.*)$ {\
    client_max_body_size 0;\
    proxy_buffering off;\
    #access_log off;\
    proxy_set_header X-Real-IP $remote_addr;\
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
    proxy_set_header X-Forwarded-Proto $scheme;\
    proxy_set_header Host $http_host;\
    proxy_connect_timeout 300;\
    proxy_http_version 1.1;\
    proxy_set_header Connection "";\
    chunked_transfer_encoding off;\
    proxy_pass http://'${TEMP_ENDPOINT}'/minio/$1;\
  }\
'
            sed -i "$REPLACE" /etc/nginx/conf.d/port_${port}.conf
            sed -i "$REPLACE" /etc/nginx/conf.d/port_443.conf
        elif [ "$TEMP_TYPE" = "DATABASE" ]; then
            echo "we are here in the DATABASE block!"
            tee -a /etc/nginx/nginx.conf > /dev/null <<EOT
stream {
    resolver 127.0.0.11 valid=30s; # Docker DNS Server

    # a hack to declare $server_us variable
    map "" \$server_$(echo $service | tr '-' '_') {
        default ${TEMP_ENDPOINT};
    }

    server {
        listen 3306;
        proxy_pass \$server_$(echo $service | tr '-' '_');
    }
}
EOT
        elif [ "$TEMP_TYPE" = "STATIC" ]; then
            REPLACE='$ i\
  location ~ ^'${TEMP_PREFIX}'/?(.*)$ {\
    root   /usr/share/nginx/html;\
    index  index.html index.htm;\
    try_files $uri /index.html;\
  }\
'
            sed -i "$REPLACE" /etc/nginx/conf.d/port_443.conf
        else
            REPLACE='$ i\
  location ~ ^'${TEMP_PREFIX}'/?(.*)$ {\
    proxy_set_header  X-Forwarded-Host $host:$server_port'${TEMP_PREFIX}';\
    proxy_set_header  X-Forwarded-Proto $scheme;\
    proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;\
    proxy_set_header  X-Real-IP $remote_addr;\
    proxy_pass http://'${TEMP_ENDPOINT}${TEMP_TARGET_PREFIX}'/$1$is_args$args;\
    # allow websocket upgrade (jupyter lab)\
    proxy_http_version 1.1;\
    proxy_set_header Upgrade $http_upgrade;\
    proxy_set_header Connection "Upgrade";\
    proxy_read_timeout 86400;\
  }\
'
            sed -i "$REPLACE" /etc/nginx/conf.d/port_${port}.conf
            sed -i "$REPLACE" /etc/nginx/conf.d/port_443.conf
        fi;
        sed -i "s|{{SUBDOMAINS}}|${SUBDOMAINS}|g" /etc/nginx/conf.d/port_${port}.conf
        sed -i "s|{{URL}}|${URL}|g" /etc/nginx/conf.d/port_${port}.conf
        sed -i "s|{{PORT}}|${port}|g" /etc/nginx/conf.d/port_${port}.conf
        sed -i "s|{{SUBDOMAINS}}|${SUBDOMAINS}|g" /etc/nginx/conf.d/port_443.conf
        sed -i "s|{{URL}}|${URL}|g" /etc/nginx/conf.d/port_443.conf
        TEMP_ENDPOINT=""
        TEMP_PREFIX=""
        TEMP_PORT=""
        TEMP_TARGET_PREFIX=""
        TEMP_TYPE=""
    fi
done

if [ "$HTTPS_PASSTHRU" = "TRUE" ]; then
    if [ ! -f "/etc/nginx/conf.d/port_80.conf" ]; then
        cp /http.conf /etc/nginx/conf.d/port_80.conf
        if [ ! -f "/etc/nginx/conf.d/port_443.conf" ]; then
            cp /https.conf /etc/nginx/conf.d/port_443.conf
        fi
    fi
    REPLACE='$ i\
  location / {\
    return 301 https://$host$request_uri;\
  }\
'
    sed -i "$REPLACE" /etc/nginx/conf.d/port_80.conf
    sed -i "s|{{SUBDOMAINS}}|${SUBDOMAINS}|g" /etc/nginx/conf.d/port_80.conf
    sed -i "s|{{URL}}|${URL}|g" /etc/nginx/conf.d/port_80.conf
    sed -i "s|{{PORT}}|80|g" /etc/nginx/conf.d/port_80.conf
    sed -i "s|{{SUBDOMAINS}}|${SUBDOMAINS}|g" /etc/nginx/conf.d/port_443.conf
    sed -i "s|{{URL}}|${URL}|g" /etc/nginx/conf.d/port_443.conf
fi
if [ ! -z "$CERTBOT_HOST" ]; then
    if [ ! -f "/etc/nginx/conf.d/port_80.conf" ]; then
        cp /http.conf /etc/nginx/conf.d/port_80.conf
    fi
    REPLACE='$ i\
  location ~ ^/.well-known/acme-challenge/?(.*)$ {\
    proxy_pass http://'${CERTBOT_HOST}';\
  }\
'
    sed -i "$REPLACE" /etc/nginx/conf.d/port_80.conf
    sed -i "s|{{SUBDOMAINS}}|${SUBDOMAINS}|g" /etc/nginx/conf.d/port_80.conf
    sed -i "s|{{URL}}|${URL}|g" /etc/nginx/conf.d/port_80.conf
    sed -i "s|{{PORT}}|80|g" /etc/nginx/conf.d/port_80.conf
fi
if [ -z "$HTTPS_PORT" ]; then
    HTTPS_PORT=443
else
    mv /etc/nginx/conf.d/port_443.conf /etc/nginx/conf.d/port_${HTTPS_PORT}.conf
fi
sed -i "s|{{HTTPS_PORT}}|${HTTPS_PORT}|g" /etc/nginx/conf.d/port_${HTTPS_PORT}.conf


if [ ! -f "/etc/nginx/conf.d/port_${HTTPS_PORT}.conf" ]; then
    nginx -g "daemon off;"
else
    mv /etc/nginx/conf.d/port_${HTTPS_PORT}.conf /tmp/port_${HTTPS_PORT}.conf
    nginx

    echo "[$(date -u '+%Y-%m-%d %H:%M:%S')][DataJoint]: Waiting for initial certs"
    while [ ! -d /etc/letsencrypt/live/${SUBDOMAINS}${URL} ]; do
        sleep 5
    done
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S')][DataJoint]: Enabling SSL feature"
    mv /tmp/port_${HTTPS_PORT}.conf /etc/nginx/conf.d/port_${HTTPS_PORT}.conf
    update_cert

    echo "[$(date -u '+%Y-%m-%d %H:%M:%S')][DataJoint]: Monitoring SSL Cert changes..."
    INIT_TIME=$(date +%s)
    LAST_MOD_TIME=$(date -r $(echo /etc/letsencrypt/live/${SUBDOMAINS}${URL}/$(ls -t /etc/letsencrypt/live/${SUBDOMAINS}${URL}/ | head -n 1)) +%s)
    DELTA=$(expr $LAST_MOD_TIME - $INIT_TIME)
    while true; do
        CURR_FILEPATH=$(ls -t /etc/letsencrypt/live/${SUBDOMAINS}${URL}/ | head -n 1)
        CURR_LAST_MOD_TIME=$(date -r $(echo /etc/letsencrypt/live/${SUBDOMAINS}${URL}/${CURR_FILEPATH}) +%s)
        CURR_DELTA=$(expr $CURR_LAST_MOD_TIME - $INIT_TIME)
        if [ "$DELTA" -lt "$CURR_DELTA" ]; then
            echo "[$(date -u '+%Y-%m-%d %H:%M:%S')][DataJoint]: Renewal: Reloading NGINX since \`$CURR_FILEPATH\` changed."
            update_cert
            DELTA=$CURR_DELTA
        else
            sleep 5
        fi
    done
fi
