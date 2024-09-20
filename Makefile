# Параметры для подключения по SSH
SSH_USER=root
SSH_HOST=147.45.245.104
PROJECT_DIR=development/docker-nginx

# Параметры репозитория
BRANCH=main

# Локальная директория проекта
LOCAL_PROJECT_DIR=.

# Имя контейнера (или сервиса в docker-compose.yml)
CONTAINER_NAME=nginx

# Цель по умолчанию
all: deploy

# Получение URL репозитория
REPO_URL=$(shell git config --get remote.origin.url)

# Правило для клонирования репозитория
clone:
	ssh $(SSH_USER)@$(SSH_HOST) 'git clone -b $(BRANCH) $(REPO_URL) $(PROJECT_DIR) || (cd $(PROJECT_DIR) && git pull origin $(BRANCH))'

# Правило для копирования проекта из текущей папки
copy:
	rsync -avz --delete --exclude-from='.gitignore' $(LOCAL_PROJECT_DIR)/ $(SSH_USER)@$(SSH_HOST):$(PROJECT_DIR)

# Правило для остановки и удаления запущенного контейнера
remove-container:
	ssh $(SSH_USER)@$(SSH_HOST) 'if [ $$(docker ps -q -f name=$(CONTAINER_NAME)) ]; then docker rm -f $(CONTAINER_NAME); fi'

# Правило для запуска Docker Compose
docker-compose-up:
	ssh $(SSH_USER)@$(SSH_HOST) 'cd $(PROJECT_DIR) && docker compose up --no-deps --build --force-recreate'

# Комплексное правило для деплоя
deploy: copy remove-container docker-compose-up

# Очистка проекта на удаленном сервере
clean:
	ssh $(SSH_USER)@$(SSH_HOST) 'rm -rf $(PROJECT_DIR)'
