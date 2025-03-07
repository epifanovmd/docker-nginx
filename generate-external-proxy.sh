#!/bin/bash

# Функция для отображения справки
show_help() {
    echo "Usage: $0 --service=<service_name> --ip=<ip_address> --ports=<port1,port2,...> [--location=<location>]"
    echo ""
    echo "Аргументы:"
    echo "  --service=<service_name>  Имя сервиса"
    echo "  --ip=<ip_address>         IP-адрес внешнего сервиса"
    echo "  --ports=<ports>           Список портов через запятую (например, 80,443)"
    echo "  --location=<location>     Необязательный путь (по умолчанию '/')"
    echo ""
    echo "Опции:"
    echo "  --help                   Показать эту справку и выйти"
}

# Проверка аргументов
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Инициализация переменных
SERVICE_NAME=""
IP_ADDRESS=""
PORTS=""
LOCATION="/"

# Разбор аргументов
for arg in "$@"; do
    case $arg in
        --service=*) SERVICE_NAME="${arg#*=}" ;;
        --ip=*) IP_ADDRESS="${arg#*=}" ;;
        --ports=*) PORTS="${arg#*=}" ;;
        --location=*) LOCATION="${arg#*=}" ;;
    esac
done

# Проверка обязательных параметров
if [[ -z "$SERVICE_NAME" || -z "$IP_ADDRESS" || -z "$PORTS" ]]; then
    echo "Ошибка: Параметры --service, --ip и --ports обязательны"
    show_help
    exit 1
fi

# Загрузка переменных из .env файла
if [ ! -f .env ]; then
    echo "Ошибка: .env файл не найден"
    exit 1
fi

source .env

# Проверка наличия переменной NGINX_HOST
if [ -z "$NGINX_HOST" ]; then
    echo "Ошибка: переменная NGINX_HOST не установлена в файле .env"
    exit 1
fi

# Определение пути к конфигурационным файлам Nginx и имени контейнера Nginx
NGINX_CONF_DIR="./conf.d/services"
NGINX_CONTAINER_NAME="nginx"

# Создание директории services, если она не существует
mkdir -p "$NGINX_CONF_DIR"

# Создание нового конфигурационного файла Nginx в указанной директории
NEW_NGINX_CONF="$NGINX_CONF_DIR/$SERVICE_NAME.conf"

# Разделяем порты на массив
IFS=',' read -r -a PORT_ARRAY <<< "$PORTS"

cat <<EOF > "$NEW_NGINX_CONF"
upstream $SERVICE_NAME {
EOF

for PORT in "${PORT_ARRAY[@]}"; do
cat <<EOF >> "$NEW_NGINX_CONF"
    server $IP_ADDRESS:$PORT;
EOF
done

cat <<EOF >> "$NEW_NGINX_CONF"
}

server {
    listen 80;
    server_name $SERVICE_NAME.$NGINX_HOST;

    location $LOCATION {
        proxy_pass http://$SERVICE_NAME;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Вызов скрипта для перезапуска Nginx
./restart_nginx.sh "$NGINX_CONTAINER_NAME"
