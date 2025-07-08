#!/bin/bash

# Определяем переменные
WEBROOT_PATH="/var/www/certbot"
EMAIL="epifanovmd@gmail.com"
SERVICE_NAME="nginx"
CRON_FILE="/tmp/cronjob"
PROJECT_DIR="/root/development/docker-nginx/" # Путь к директории с docker-compose.yml

# Получаем домены из аргументов командной строки
DOMAINS=("$@")

# Проверяем, что переданы домены
if [ ${#DOMAINS[@]} -eq 0 ]; then
  echo "Ошибка: Не указаны домены. Использование: $0 domain1 domain2 ..."
  exit 1
fi

# Флаг успешного создания сертификата
SUCCESS=false

# Создаём и обновляем сертификаты для каждого домена
for DOMAIN in "${DOMAINS[@]}"; do
  echo "Создаем сертификат для домена: $DOMAIN"
  cd $PROJECT_DIR && docker compose --profile certbot run --rm certbot certonly --webroot -w $WEBROOT_PATH -d $DOMAIN --email $EMAIL --force-renewal
  if [ $? -eq 0 ]; then
    SUCCESS=true
    echo "Сертификат для $DOMAIN успешно создан/обновлен"
  else
    echo "Ошибка при создании сертификата для $DOMAIN"
  fi
done

# Если хотя бы один сертификат успешно создан
if [ "$SUCCESS" = true ]; then
  docker stop certbot-nginx

  # Перезапускаем сервис nginx для применения новых сертификатов
  echo "Перезапускаем сервис $SERVICE_NAME..."
  cd $PROJECT_DIR && docker compose restart $SERVICE_NAME

  # Команда для автоматического обновления и перезапуска сервиса
  RENEW_COMMAND="cd $PROJECT_DIR && docker stop nginx && docker compose --profile certbot run --rm certbot renew --webroot -w $WEBROOT_PATH --force-renewal && docker stop certbot-nginx && docker compose restart $SERVICE_NAME"

  # Добавляем текущее содержимое crontab в файл
  crontab -l > $CRON_FILE 2>/dev/null || touch $CRON_FILE

  # Проверяем, есть ли уже задание на обновление
  if ! grep -q "$RENEW_COMMAND" $CRON_FILE; then
    # Добавляем новое задание в crontab (1-го числа каждого месяца)
    echo "0 0 1 * * $RENEW_COMMAND" >> $CRON_FILE
    # Устанавливаем обновленный crontab
    crontab $CRON_FILE
    echo -e "\nЗадание cron для обновления сертификатов добавлено."

    # Выводим текущий crontab
    echo -e "\nТекущие задания cron:"
    crontab -l
  else
    echo -e "\nЗадание cron для обновления сертификатов уже существует."
    echo -e "\nТекущие задания cron:"
    crontab -l
  fi
else
  echo -e "\nНе удалось создать ни один сертификат. Задание cron не добавлено."
fi

# Удаляем временный файл
rm -f $CRON_FILE
