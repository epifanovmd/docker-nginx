#!/bin/bash

# Функция для отображения справки
show_help() {
    echo "Usage: $0 <container_name> --ports=<ports> [--location=<location>] [--domain=<domain>]"
    echo ""
    echo "Аргументы:"
    echo "  <container_name>       Имя контейнера Docker"
    echo "  --ports=<ports>        Порты через запятую (например, 80,443)"
    echo "  --location=<location>  Необязательный путь (по умолчанию '/')"
    echo "  --domain=<domain>      Необязательный домен (по умолчанию container_name)"
    echo ""
    echo "Опции:"
    echo "  --help                 Показать эту справку и выйти"
}

# Проверка аргументов
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ "$#" -lt 2 ]]; then
    echo "Ошибка: Неверное количество аргументов"
    show_help
    exit 1
fi

# Разбор аргументов
CONTAINER_NAME=$1
PORTS=""
LOCATION="/"
DOMAIN=""

for arg in "$@"; do
    case $arg in
        --ports=*) PORTS="${arg#*=}" ;;
        --location=*) LOCATION="${arg#*=}" ;;
        --domain=*) DOMAIN="${arg#*=}" ;;
    esac
done

if [[ -z "$PORTS" ]]; then
    echo "Ошибка: Параметр --ports обязателен"
    show_help
    exit 1
fi

# Если домен не указан, использовать имя контейнера
DOMAIN=${DOMAIN:-$CONTAINER_NAME}

IFS=',' read -r -a PORTS_ARRAY <<< "$PORTS"

# Загрузка переменных из .env файла
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

source .env

if [ -z "$NGINX_HOST" ] || [ -z "$NGINX_LOCALHOST" ]; then
    echo "Ошибка: переменные NGINX_HOST или NGINX_LOCALHOST не установлены в .env"
    exit 1
fi

NGINX_CONF_DIR="./conf.d/dockers"
NGINX_CONTAINER_NAME="nginx"

mkdir -p "$NGINX_CONF_DIR"

# Получение всех портов контейнера
HOST_PORTS=($(docker inspect "$CONTAINER_NAME" | awk -F'[:,]' '/HostPort/ {gsub(/"/, "", $2); print $2}' | sort -u))

MATCHED_PORTS=()
for PORT in "${PORTS_ARRAY[@]}"; do
  if [[ " ${HOST_PORTS[*]} " == *" $PORT "* ]]; then
    MATCHED_PORTS+=("$PORT")
  else
    echo "Предупреждение: Порт $PORT не найден в сопоставлениях контейнера $CONTAINER_NAME"
  fi
done

if [ ${#MATCHED_PORTS[@]} -eq 0 ]; then
    echo "Ошибка: Не найдено совпадающих портов для контейнера $CONTAINER_NAME"
    exit 1
fi

NEW_NGINX_CONF="$NGINX_CONF_DIR/$CONTAINER_NAME.conf"

cat <<EOF > "$NEW_NGINX_CONF"
upstream $CONTAINER_NAME {
EOF

for PORT in "${MATCHED_PORTS[@]}"; do
cat <<EOF >> "$NEW_NGINX_CONF"
    server $NGINX_LOCALHOST:$PORT;
EOF
done

cat <<EOF >> "$NEW_NGINX_CONF"
}

server {
    listen 80;
    server_name $DOMAIN.$NGINX_HOST;

    location $LOCATION {
        proxy_pass http://$CONTAINER_NAME;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

./restart_nginx.sh "$NGINX_CONTAINER_NAME"
