#!/bin/bash

# Функция для отображения справки
show_help() {
  echo "Использование: $0 --location=<location_path> --static-dir=<static_dir>"
  echo ""
  echo "Опции:"
  echo "  --location=<location_path>  Путь расположения для конфигурации Nginx (по умолчанию '/files')"
  echo "  --static-dir=<static_dir>   Путь к статическому каталогу (обязательно)"
  echo "  --help                      Показать это сообщение и выйти"
}

# Значения по умолчанию
LOCATION_PATH="/files"
STATIC_DIR=""

# Разбор аргументов
for arg in "$@"; do
  case $arg in
    --location=*) LOCATION_PATH="${arg#*=}" ;;
    --static-dir=*) STATIC_DIR="${arg#*=}" ;;
    --help) show_help; exit 0 ;;
  esac
done

# Проверка обязательного параметра STATIC_DIR
if [ -z "$STATIC_DIR" ]; then
  echo "Ошибка: Параметр --static-dir обязателен"
  show_help
  exit 1
fi

# Определение пути к конфигурационному файлу Nginx
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

# Вставка нового location блока в конец блока server
awk -v static_dir="$STATIC_DIR" -v location_path="$LOCATION_PATH" '
/server {/ { inside_server = 1 }
inside_server && /^}/ {
    print "    location " location_path " {";
    print "        alias " static_dir ";";
    print "        autoindex on;";
    print "     }";
    inside_server = 0;
}
{ print }
' $NGINX_CONF_FILE > $TEMP_CONF_FILE

# Замена старого конфиг файла новым
mv $TEMP_CONF_FILE $NGINX_CONF_FILE

# Перезагрузка Nginx
./restart_nginx.sh $NGINX_CONTAINER_NAME
