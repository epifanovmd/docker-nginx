#!/bin/bash

# Функция для отображения справки
show_help() {
  echo "Использование: $0 <location_path> [<static_dir>]"
  echo ""
  echo "Аргументы:"
  echo "  <location_path>    Путь расположения для конфигурации Nginx"
  echo "  <static_dir>       (Необязательно) Путь к статическому каталогу"
  echo ""
  echo "Опции:"
  echo "  --help             Показать это сообщение и выйти"
}

# Проверка наличия аргументов
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  if [ "$1" == "--help" ]; then
    show_help
    exit 0
  else
    echo "Ошибка: Неверное количество аргументов"
    show_help
    exit 1
  fi
fi

LOCATION_PATH=$1
STATIC_DIR=$2

# Загрузка переменных из .env файла
if [ ! -f .env ]; then
  echo "Ошибка: файл .env не найден"
  exit 1
fi

source .env

# Проверка наличия переменных NGINX_HOST и NGINX_PORT
if [ -z "$NGINX_HOST" ] || [ -z "$NGINX_PORT" ]; then
  echo "Ошибка: переменные NGINX_HOST или NGINX_PORT не установлены в файле .env"
  exit 1
fi

# Если STATIC_DIR не передан, берем его из .env
if [ -z "$STATIC_DIR" ]; then
  if [ -z "$DEFAULT_STATIC_DIR" ]; then
    echo "Ошибка: переменная DEFAULT_STATIC_DIR не установлена в файле .env и аргумент static_dir не передан"
    exit 1
  fi
  STATIC_DIR=$DEFAULT_STATIC_DIR
fi

# Определение пути к конфигурационному файлу Nginx и имени контейнера Nginx
NGINX_CONF_FILE="./conf.d/default.conf"
NGINX_CONTAINER_NAME="nginx"

# Проверка на наличие дублирующего location блока
if grep -q "location $LOCATION_PATH" "$NGINX_CONF_FILE"; then
  # Удаление блока location
  awk -v loc="$LOCATION_PATH" '
    $0 ~ "location " loc " {" { delete_block = 1; next }
    delete_block && /}/ { delete_block = 0; next }
    !delete_block
  ' "$NGINX_CONF_FILE" > "${NGINX_CONF_FILE}.tmp" && mv "${NGINX_CONF_FILE}.tmp" "$NGINX_CONF_FILE"
fi

# Создание временного файла для нового конфигурационного файла
TEMP_CONF_FILE=$(mktemp)

# Вставка нового location блока в конец блока server с проверкой на пустую строку
awk -v static_dir="$STATIC_DIR" -v location_path="$LOCATION_PATH" '
/server_name '"$NGINX_HOST"'/ { inside_server = 1 }
inside_server && /^}/ {
    print "    location " location_path " {";
    print "        alias " static_dir ";";
    print "     }";
    inside_server = 0;
}
{ print }
' $NGINX_CONF_FILE > $TEMP_CONF_FILE

# Замена старого конфиг файла новым
mv $TEMP_CONF_FILE $NGINX_CONF_FILE

# Перезагрузка Nginx
./restart_nginx.sh $NGINX_CONTAINER_NAME
