STACK_FILES := $(sort $(wildcard caddy/stacks/*.yaml))
COMPOSE := docker compose -f caddy/compose.yaml $(addprefix -f ,$(STACK_FILES)) --env-file .env

.PHONY: setup cert up down ps logs

# Every stack file names one external network (`name:` under `networks:`).
# Fail with the stack file and the DSS command that creates the network.
setup:
	@test -f .env || cp .env.example .env
	@for f in $(STACK_FILES); do \
		for net in $$(awk '/^[[:space:]]+name:/ {print $$2}' "$$f"); do \
			docker network inspect "$$net" >/dev/null 2>&1 || { \
				prefix=$$(echo "$$net" | sed 's/_*traefik_proxy$$//'); \
				echo "Network $$net (from $$f) is missing."; \
				echo "Run 'make setup' in docker-shared-services$${prefix:+ with DSS_NAME=$$prefix} first."; \
				exit 1; \
			}; \
		done; \
	done

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
