.PHONY: setup data dbt-build test lint infra-validate dashboard run clean

PYTHON ?= .venv/bin/python
DBT ?= .venv/bin/dbt

setup:
	uv venv .venv
	uv pip install -e ".[dev]"

data:
	$(PYTHON) -m saas_revenue.ingest

dbt-build:
	cd dbt_project && $(DBT) build --profiles-dir . --target dev_local

run: data dbt-build

test:
	$(PYTHON) -m pytest

lint:
	.venv/bin/ruff check src tests
	.venv/bin/ruff format --check src tests

infra-validate:
	terraform fmt -check -recursive infra/terraform
	cd infra/terraform/environments/dev && terraform init -backend=false && terraform validate

dashboard:
	.venv/bin/streamlit run src/saas_revenue/dashboard.py

clean:
	rm -rf data/ dbt_project/target/ dbt_project/logs/ .pytest_cache/ .ruff_cache/
