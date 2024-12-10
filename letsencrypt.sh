#!/bin/bash

# Определяем переменные
WEBROOT_PATH="/var/www/certbot"
DOMAINS=("force-dev.ru" "wireguard.force-dev.ru")
EMAIL="epifanovmd@gmail.com"
SERVICE_NAME="nginx"
CRON_FILE="/tmp/cronjob"

# Флаг успешного создания сертификата
SUCCESS=false

# Создаём и обновляем сертификаты для каждого домена
for DOMAIN in "${DOMAINS[@]}"; do
  docker compose run --rm certbot certonly --webroot -w $WEBROOT_PATH -d $DOMAIN --email $EMAIL --force-renewal
  if [ $? -eq 0 ]; then
    SUCCESS=true
  fi
done

# Если хотя бы один сертификат успешно создан
if [ "$SUCCESS" = true ]; then
  # Команда для автоматического обновления и перезапуска сервиса
  RENEW_COMMAND="docker compose run --rm certbot renew --webroot -w $WEBROOT_PATH --force-renewal && docker compose restart $SERVICE_NAME"

  # Добавляем текущее содержимое crontab в файл
  crontab -l > $CRON_FILE 2>/dev/null

  # Проверяем, есть ли уже задание на обновление
  if ! grep -q "$RENEW_COMMAND" $CRON_FILE; then
    # Добавляем новое задание в crontab (1-го числа каждого месяца)
    echo "0 0 1 * * $RENEW_COMMAND" >> $CRON_FILE
    # Устанавливаем обновленный crontаб
    crontab $CRON_FILE
    echo "Задание cron для обновления сертификатов добавлено."
  else
    echo "Задание cron для обновления сертификатов уже существует."
  fi
else
  echo "Не удалось создать ни один сертификат."
fi

# Удаляем временный файл
rm $CRON_FILE
