#!/bin/bash

# Функция для отображения справки
show_help() {
    echo "Usage: $0 <container_name> <ports>"
    echo ""
    echo "Аргументы:"
    echo "  <container_name>  Имя контейнера Docker"
    echo "  <ports>           Порты через запятую (например, 80,443)"
    echo "  [location]       Необязательный путь (по умолчанию '/')"
    echo ""
    echo "Опции:"
    echo "  --help            Показать эту справку и выйти"
}

# Проверка наличия аргументов
if [ "$#" -ne 2 ]; then
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
IFS=',' read -r -a PORTS <<< "$2"
LOCATION=${4:-/} # Устанавливаем значение по умолчанию для location

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

# Получение всех портов хоста, к которым привязан любой порт контейнера с использованием awk
HOST_PORTS=($(docker inspect $CONTAINER_NAME | awk -F'[:,]' '/HostPort/ {gsub(/"/, "", $2); print $2}' | sort -u))

# Проверка, что указанные порты присутствуют в сопоставлениях портов контейнера
MATCHED_PORTS=()
for PORT in "${PORTS[@]}"; do
  if [[ " ${HOST_PORTS[*]} " == *" $PORT "* ]]; then
    MATCHED_PORTS+=("$PORT")
  else
    echo "Предупреждение: Порт $PORT не найден в сопоставлениях портов контейнера $CONTAINER_NAME"
  fi
done

if [ ${#MATCHED_PORTS[@]} -eq 0 ]; then
    echo "Ошибка: Не удалось найти сопоставление указанных портов для контейнера $CONTAINER_NAME"
    exit 1
fi

# Создание нового конфигурационного файла Nginx в указанной директории
NEW_NGINX_CONF="$NGINX_CONF_DIR/$CONTAINER_NAME.conf"

cat <<EOF > $NEW_NGINX_CONF
upstream $CONTAINER_NAME {
EOF

for PORT in "${MATCHED_PORTS[@]}"; do
cat <<EOF >> $NEW_NGINX_CONF
    server $NGINX_LOCALHOST:$PORT;
EOF
done

cat <<EOF >> $NEW_NGINX_CONF
}

server {
    listen 80;
    server_name $CONTAINER_NAME.$NGINX_HOST;

    location $LOCATION {
        proxy_pass http://$CONTAINER_NAME;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Вызов скрипта для перезапуска Nginx
./restart_nginx.sh $NGINX_CONTAINER_NAME
