#!/bin/bash

# Функция для отображения справки
show_help() {
  echo "Использование: $0 <static_dir> <location_path>"
  echo ""
  echo "Аргументы:"
  echo "  <static_dir>       Путь к статическому каталогу"
  echo "  <location_path>    Путь расположения для конфигурации Nginx"
  echo ""
  echo "Опции:"
  echo "  --help             Показать это сообщение и выйти"
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

STATIC_DIR=$1
LOCATION_PATH=$2

# Загрузка переменных из .env файла
if [ ! -f .env ]; then
  echo "Ошибка: файл .env не найден"
  exit 1
fi

source .env

# Проверка наличия переменных NGINX_HOST и NGINX_LOCALHOST
if [ -z "$NGINX_HOST" ] || [ -z "$NGINX_LOCALHOST" ]; then
  echo "Ошибка: переменные NGINX_HOST или NGINX_LOCALHOST не установлены в файле .env"
  exit 1
fi

# Определение пути к конфигурационному файлу Nginx и имени контейнера Nginx
NGINX_CONF_FILE="./conf.d/default.conf"
NGINX_CONTAINER_NAME="nginx"

# Создание временного файла для нового конфигурационного файла
TEMP_CONF_FILE=$(mktemp)

# Проверка на наличие дублирующего location блока
if grep -q "location $LOCATION_PATH" $NGINX_CONF_FILE; then
  echo "Ошибка: Дублирующий блок location для $LOCATION_PATH уже существует в $NGINX_CONF_FILE"
  exit 1
fi

# Вставка нового location блока в конец блока server
awk -v static_dir="$STATIC_DIR" -v location_path="$LOCATION_PATH" '
/server {/ { inside_server = 1 }
inside_server && /^}/ {
    print "";
    print "    location " location_path " {";
    print "        alias " static_dir ";";
    print "        try_files \\$uri \\$uri/ =404;";
    inside_server = 0;
}
{ print }
' $NGINX_CONF_FILE > $TEMP_CONF_FILE

# Замена старого конфиг файла новым
mv $TEMP_CONF_FILE $NGINX_CONF_FILE

# Перезагрузка Nginx
./restart_nginx.sh $NGINX_CONTAINER_NAME
