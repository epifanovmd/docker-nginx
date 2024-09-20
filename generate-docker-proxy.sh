#!/bin/bash

# Функция для отображения справки
show_help() {
    echo "Usage: $0 <container_name>"
    echo ""
    echo "Аргументы:"
    echo "  <container_name>  Имя контейнера Docker"
    echo ""
    echo "Опции:"
    echo "  --help           Показать эту справку и выйти"
}

# Проверка наличия аргументов
if [ "$#" -ne 1 ]; then
  if [ "$1" == "--help" ]; then
    show_help
    exit 0
  else
    echo "Ошибка: Неверное количество аргументов"
    show_help
    exit 1
  fi
fi

CONTAINER_NAME=$1

# Загрузка переменных из .env файла
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

source .env

# Проверка наличия переменных NGINX_HOST и NGINX_LOCALHOST
if [ -z "$NGINX_HOST" ] || [ -z "$NGINX_LOCALHOST" ]; then
    echo "Ошибка: переменные NGINX_HOST или NGINX_LOCALHOST не установлены в файле .env"
    exit 1
fi

# Определение пути к конфигурационным файлам Nginx и имени контейнера Nginx
NGINX_CONF_DIR="./conf.d/dockers"
NGINX_CONTAINER_NAME="nginx"

# Создание директории dockers, если она не существует
mkdir -p $NGINX_CONF_DIR

# Получение первого порта хоста, к которому привязан любой порт контейнера с использованием awk и sed
HOST_PORT=$(docker inspect $CONTAINER_NAME | awk '/"HostPort"/ {gsub(/"/, "", $2); print $2}' | head -n 1)

if [ -z "$HOST_PORT" ];then
    echo "Ошибка: не удалось найти сопоставление порта для контейнера $CONTAINER_NAME"
    exit 1
fi

# Создание нового конфигурационного файла Nginx в указанной директории
NEW_NGINX_CONF="$NGINX_CONF_DIR/$CONTAINER_NAME.conf"

cat <<EOF > $NEW_NGINX_CONF
server {
    listen 80;
    server_name $CONTAINER_NAME.$NGINX_HOST;

    location / {
        proxy_pass http://$NGINX_LOCALHOST:$HOST_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Вызов скрипта для перезапуска Nginx
./restart_nginx.sh $NGINX_CONTAINER_NAME
