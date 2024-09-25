#!/bin/bash

# Запрос доменного имени у пользователя
read -p "Введите доменное имя (например, example.com): " DOMAIN

# Запрос срока действия сертификата у пользователя
read -p "Введите срок действия сертификата в днях (по умолчанию 365 дней): " INPUT_DAYS
DAYS=${INPUT_DAYS:-365}  # Используем введенное значение или по умолчанию 365 дней

# Переменные
KEY_FILE="${DOMAIN}.key" # Имя файла закрытого ключа
CSR_FILE="${DOMAIN}.csr" # Имя файла запроса на сертификат (CSR)
CRT_FILE="${DOMAIN}.crt" # Имя файла самоподписанного сертификата
EXT_FILE="${DOMAIN}.ext" # Имя файла конфигурации расширений

# Создание закрытого ключа
openssl genpkey -algorithm RSA -out $KEY_FILE -pkeyopt rsa_keygen_bits:2048
# Используем OpenSSL для генерации закрытого ключа алгоритма RSA с длиной 2048 бит

# Создание CSR (запроса на сертификат)
openssl req -new -key $KEY_FILE -out $CSR_FILE -subj "/CN=${DOMAIN}"
# Создаем запрос на сертификат (CSR) с помощью OpenSSL, используя ранее созданный закрытый ключ и указывая доменное имя

# Создание файла конфигурации расширений
cat > $EXT_FILE <<EOL
authorityKeyIdentifier=keyid,issuer          # Идентификатор ключа органа сертификации (CA)
basicConstraints=CA:FALSE                    # Указывает, что это не CA-сертификат

# Определяет использование ключа
# digitalSignature - Используется для проверки цифровой подписи
# nonRepudiation -  Обеспечивает невозможность отказа от авторства
# keyEncipherment - Используется для шифрования ключей
# dataEncipherment -Используется для шифрования данных

keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment  # Используется для шифрования данных

# Альтернативные имена субъекта
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
EOL
# Создаем файл конфигурации расширений для сертификата

# Создание самоподписанного сертификата
openssl x509 -req -days $DAYS -in $CSR_FILE -signkey $KEY_FILE -out $CRT_FILE -extfile $EXT_FILE
# Создаем самоподписанный сертификат с использованием запроса на сертификат (CSR), закрытого ключа и файла расширений

echo "Созданы файлы:"
echo "Закрытый ключ: $KEY_FILE"
echo "Запрос на сертификат: $CSR_FILE"
echo "Самоподписанный сертификат: $CRT_FILE"
echo "Файл конфигурации расширений: $EXT_FILE"
# Выводим информацию о созданных файлах
