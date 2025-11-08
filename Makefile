
.PHONY:	all build down full-down data rm-data full-clean re prune

BASE_DATA_DIR = /home/$(USER)/data

DATA_DIRS = $(BASE_DATA_DIR)/db \
			$(BASE_DATA_DIR)/wordpress \
			$(BASE_DATA_DIR)/vault-data \
			$(BASE_DATA_DIR)/vault-logs \
			$(BASE_DATA_DIR)/vault-creds/nginx \
			$(BASE_DATA_DIR)/vault-creds/wordpress

COMPOSE_FILE = ./srcs/docker-compose.yml

all : data build
	docker compose --env-file="./secrets/.env" -f $(COMPOSE_FILE) up -d

build :
	docker compose --env-file="./secrets/.env" -f $(COMPOSE_FILE) build

down :
	docker compose --env-file="./secrets/.env" -f $(COMPOSE_FILE) down

full-down : down
	docker compose --env-file="./secrets/.env" -f $(COMPOSE_FILE) down -v --rmi all

data :	
	@mkdir -p $(DATA_DIRS)

rm-data:
	@sudo rm -rf $(BASE_DATA_DIR)

prune:
	docker builder prune -af

full-clean : full-down rm-data prune

re : full-clean all