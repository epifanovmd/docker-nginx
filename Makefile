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

# Получение URL репозитория
REPO_URL=$(shell git config --get remote.origin.url)

# Цель по умолчанию
all: deploy

# Переменная для использования SSH
USE_SSH=$(filter ssh,$(MAKECMDGOALS))

# Префикс для команд (локально или по SSH)
CMD_PREFIX=$(if $(USE_SSH),ssh $(SSH_USER)@$(SSH_HOST),)

# Правило для клонирования репозитория
clone:
	$(CMD_PREFIX) git clone -b $(BRANCH) $(REPO_URL) $(PROJECT_DIR) || (cd $(PROJECT_DIR) && git pull origin $(BRANCH))

# Правило для копирования проекта из текущей папки
copy:
	rsync -avz --delete --exclude-from='.gitignore' $(LOCAL_PROJECT_DIR)/ $(SSH_USER)@$(SSH_HOST):$(PROJECT_DIR)

# Правило для остановки и удаления запущенного контейнера
remove-container:
	$(CMD_PREFIX) if [ $$(docker ps -q -f name=$(CONTAINER_NAME)) ]; then docker rm -f $(CONTAINER_NAME); fi

# Правило для запуска Docker Compose
docker-compose-up:
	$(CMD_PREFIX) cd $(PROJECT_DIR) && docker compose up --no-deps --build --force-recreate

# Комплексное правило для деплоя
deploy: copy remove-container docker-compose-up

# Очистка проекта на удаленном сервере
clean:
	$(CMD_PREFIX) rm -rf $(PROJECT_DIR)

# Проверка состояния контейнеров
status:
	$(CMD_PREFIX) docker ps -a

# Просмотр логов контейнера
logs:
	$(CMD_PREFIX) docker logs $(CONTAINER_NAME)

# Перезапуск контейнера
restart-container:
	$(CMD_PREFIX) docker restart $(CONTAINER_NAME)

# Обновление всех образов Docker
update-images:
	$(CMD_PREFIX) docker pull $(REPO_URL)

# Создание резервной копии проекта
backup:
	$(CMD_PREFIX) tar czf $(PROJECT_DIR)_backup_$(shell date +%Y%m%d%H%M%S).tar.gz -C $(PROJECT_DIR) .

# Убрать --ssh из целей make
%:
	@:
