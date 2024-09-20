#!/bin/bash

# Имя контейнера по умолчанию из docker-compose.yml
DEFAULT_CONTAINER_NAME="nginx"

# Функция для отображения справки
show_help() {
    echo "Usage: $0 [container_name]"
    echo ""
    echo "Options:"
    echo "  container_name   Имя контейнера Nginx (по умолчанию: $DEFAULT_CONTAINER_NAME)"
    echo "  --help           Показать эту справку и выйти"
}

# Проверка наличия аргументов и установка имени контейнера
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

NGINX_CONTAINER_NAME=${1:-$DEFAULT_CONTAINER_NAME}

# Проверка, запущен ли контейнер Nginx
if [ $(docker ps -q -f name=$NGINX_CONTAINER_NAME) ]; then
  # Если контейнер запущен, перезапускаем его
  docker exec $NGINX_CONTAINER_NAME nginx -s reload
  echo "Nginx перезапущен."
else
  # Если контейнер не запущен, запускаем его заново
  echo "Контейнер Nginx не запущен. Запуск с помощью docker compose up..."
  docker compose up -d $NGINX_CONTAINER_NAME
  echo "Nginx запущен."
fi
