COMPOSE := docker compose -f caddy/compose.yaml --env-file .env

.PHONY: setup cert up down ps logs

setup:
	@test -f .env || cp .env.example .env
	@docker network inspect traefik_proxy >/dev/null 2>&1 || { \
		echo "Network traefik_proxy is missing. Run 'make setup' in docker-shared-services first."; \
		exit 1; \
	}

cert:
	@./scripts/gen-certs.sh caddy/certs

up: setup
	@test -f caddy/certs/server.crt && test -f caddy/certs/server.key || { \
		echo "Missing caddy/certs/server.crt or server.key. Run 'make cert' first."; \
		exit 1; \
	}
	@$(COMPOSE) up -d

down:
	@$(COMPOSE) down

ps:
	@$(COMPOSE) ps

logs:
	@$(COMPOSE) logs -f
