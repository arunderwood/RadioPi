.PHONY: bootstrap lint

bootstrap:
	uv sync
	uv run ansible-galaxy install -r requirements.yml

lint:
	uv run ansible-lint
