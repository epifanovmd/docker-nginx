#!/bin/sh

# Генерация конфигурационного файла Nginx из шаблона
envsubst '${NGINX_HOST}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

chown -R www-data:www-data /var/www/files
chmod -R 755 /var/www/files

# Запуск Nginx
exec nginx -g 'daemon off;'
