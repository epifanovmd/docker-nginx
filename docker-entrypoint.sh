#!/bin/sh

## Генерация конфигурационного файла Nginx из шаблона, если он не существует
if [ ! -f /etc/nginx/conf.d/default.conf ]; then
    envsubst '${NGINX_HOST}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf
fi

chown -R www-data:www-data /var/www/files
chmod -R 755 /var/www/files

# Запуск Nginx
exec nginx -g 'daemon off;'
