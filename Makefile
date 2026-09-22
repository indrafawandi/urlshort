.PHONY: install run test lint up down logs

install:
	python -m venv .venv
	. .venv/bin/activate && pip install -r requirements-dev.txt

run:
	. .venv/bin/activate && uvicorn app.main:app --reload

test:
	. .venv/bin/activate && pytest --cov=app --cov-report=term-missing

lint:
	. .venv/bin/activate && ruff check app tests

up:
	docker compose up --build

down:
	docker compose down -v

logs:
	docker compose logs -f api
