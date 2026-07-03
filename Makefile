.PHONY: up down build shell migrate fresh test lint format pr-check

up:
	docker compose up -d
	@echo "✅ TsuriCast environment started!"
	@echo "📱 API: http://localhost:8082"

down:
	docker compose down

build:
	docker compose build

shell:
	docker compose exec app bash

migrate:
	docker compose exec app php artisan migrate

fresh:
	docker compose exec app php artisan migrate:fresh --seed

test:
	docker compose exec app php artisan test $(TESTS)

lint:
	docker compose exec app ./vendor/bin/pint --test
	@echo "✅ Code style check completed!"

format:
	docker compose exec app ./vendor/bin/pint
	@echo "✅ Code formatted!"

pr-check: lint test
	@echo ""
	@echo "🎉 All PR checks passed!"
