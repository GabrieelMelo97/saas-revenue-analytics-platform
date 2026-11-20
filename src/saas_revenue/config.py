"""Environment-aware configuration for local DuckDB and GCP BigQuery parity."""

from __future__ import annotations

from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables or .env."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: Literal["local", "dev", "prod"] = "local"
    target_backend: Literal["local", "gcp"] = "local"

    # Local paths
    local_duckdb_path: Path = Path("data/warehouse/saas_revenue.duckdb")
    local_data_dir: Path = Path("data/raw")
    local_quarantine_dir: Path = Path("data/quarantine")

    # Deterministic generator parameters
    generator_seed: int = 42
    num_accounts: int = 250

    # GCP settings (used only when target_backend == "gcp")
    gcp_project_id: str = "your-gcp-project-id"
    gcp_region: str = "us-central1"
    gcp_raw_bucket: str = "your-gcp-project-id-saas-rev-raw-dev"
    gcp_bq_dataset_raw: str = "raw"
    gcp_bq_dataset_marts: str = "marts"


def get_settings() -> Settings:
    """Return validated application settings."""
    return Settings()
