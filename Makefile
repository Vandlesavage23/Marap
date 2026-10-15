.PHONY: up down test lint
up:
	docker compose -f infra/docker-compose.yml up -d
down:
	docker compose -f infra/docker-compose.yml down
test:
	cd backend && uv run pytest
lint:
	cd backend && uv run ruff check . && uv run ruff format --check . && uv run mypy mc && uv run lint-imports
