#!/bin/bash
set -x
set -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

sudo cat <<eos | sudo tee /etc/nginx/sites-available/graphile.${HTTP_PORT_LISTENING}.agoston-dev.io.conf
server {
    listen 443 ssl;
    server_name graphile.${HTTP_PORT_LISTENING}.agoston-dev.io;

    ssl_protocols TLSv1.3 TLSv1.2;
    ssl_ciphers "HIGH:!aNULL:!MD5:!ADH:!DH:!RC4:!RSA";
    ssl_prefer_server_ciphers on;
    ssl_certificate     /etc/ssl/graphile.${HTTP_PORT_LISTENING}.agoston-dev.io.crt;
    ssl_certificate_key /etc/ssl/graphile.${HTTP_PORT_LISTENING}.agoston-dev.io.key;

    access_log /var/log/nginx/access.graphile.${HTTP_PORT_LISTENING}.agoston-dev.io.log;
    error_log /var/log/nginx/error.graphile.${HTTP_PORT_LISTENING}.agoston-dev.io.log;

    location / {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Cookie $http_cookie;
        proxy_cache_bypass $http_upgrade;
        proxy_pass http://127.0.0.1:${HTTP_PORT_LISTENING};
      }

}

server {
    listen 80;
    server_name graphile.${HTTP_PORT_LISTENING}.agoston-dev.io;
    return 301 https://graphile.${HTTP_PORT_LISTENING}.agoston-dev.io$request_uri;
}
eos

sudo ln -fs /etc/nginx/sites-available/graphile.${HTTP_PORT_LISTENING}.agoston-dev.io.conf /etc/nginx/sites-enabled/graphile.${HTTP_PORT_LISTENING}.agoston-dev.io.conf
