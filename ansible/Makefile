.PHONY: bootstrap lint test check

TEST_PLAYBOOKS := $(wildcard tests/*.yml)

bootstrap:
	uv sync
	uv run ansible-galaxy install -r requirements.yml

lint:
	uv run ansible-lint

test:
	@for pb in $(TEST_PLAYBOOKS); do \
		echo "==> $$pb"; \
		uv run ansible-playbook $$pb || exit $$?; \
	done

check: lint test
