# ADR-002: Orquestração Serverless com Cloud Run Jobs + Cloud Scheduler em vez de Cloud Composer

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto
Para executar pipelines diários de ingestão + `dbt build` no BigQuery, times frequentemente adotam o **Cloud Composer (Managed Airflow)** por hábito. Entretanto, o Cloud Composer mantém um cluster GKE ativo 24/7 com custo mínimo superior a **US\$ 300/mês**, mesmo quando o pipeline roda apenas 5 minutos por dia.

## Decisão
Orquestrar o container de ingestão + `dbt build` utilizando **Cloud Run Jobs** disparado por **Cloud Scheduler** (cron diário), com imagem versionada no **Artifact Registry** e Service Account dedicada com privilégio mínimo.

## Alternativas Consideradas
1. **Cloud Composer (Airflow):** excelente para DAGs com centenas de tarefas heterogêneas e sensores complexos, mas financeiramente desproporcional (FinOps negativo) para um pipeline de Analytics Engineering focado em dbt.
2. **Cloud Functions:** limite de memória/timeout mais restrito e menor flexibilidade de empacotamento para `dbt-bigquery` + dependências Python.

## Consequências & Trade-offs
- **Positivas:** modelo **scale-to-zero** com custo estimado de **US\$ 0,00 a < US\$ 1,50/mês** dentro do Free Tier da GCP; zero manutenção de cluster Kubernetes; deploy simples via Docker + Terraform.
- **Negativas / Trade-offs:** não oferece interface gráfica nativa de DAGs complexas com retries por task individual (em cenários de crescimento com 50+ fontes independentes, migrar a camada de agendamento para Dagster/Airflow mantendo o mesmo container dbt).
