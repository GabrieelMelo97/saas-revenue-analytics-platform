FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DBT_PROFILES_DIR=/app/dbt_project

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml README.md ./
COPY src/ ./src/
COPY dbt_project/ ./dbt_project/

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir ".[gcp]"

# Non-root user for container security best practices
RUN useradd --create-home appuser && chown -R appuser:appuser /app
USER appuser

ENTRYPOINT ["sh", "-c", "python -m saas_revenue.ingest && cd /app/dbt_project && dbt build --target gcp_bigquery"]
