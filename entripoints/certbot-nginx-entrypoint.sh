#!/bin/sh

## Генерация конфигурационного файла Nginx из шаблона, если он не существует
if [ ! -f /etc/nginx/conf.d/default.conf ]; then
    envsubst '${NGINX_HOST}' < /etc/nginx/templates/default-certbot.conf.template > /etc/nginx/conf.d/default.conf
fi

# Запуск Nginx
exec nginx -g 'daemon off;'
