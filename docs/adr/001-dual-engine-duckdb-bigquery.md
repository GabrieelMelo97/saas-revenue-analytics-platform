# ADR-001: Arquitetura Dual-Engine (DuckDB Local + BigQuery na GCP)

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto
Projetos de Analytics Engineering voltados para BigQuery frequentemente enfrentam dois problemas:
1. Feedback lento e custo de desenvolvimento/CI quando cada teste de SQL exige conexão e faturamento na nuvem.
2. Impossibilidade de avaliadores técnicos ou novos desenvolvedores executarem o projeto localmente sem credenciais GCP.

## Decisão
Adotar uma arquitetura **Dual-Engine** no `dbt Core` usando um único código SQL ANSI compatível entre:
- **`dev_local` (`dbt-duckdb`):** execução local e no GitHub Actions CI com custo **\$0**, em poucos segundos e 100% reproduzível.
- **`gcp_bigquery` (`dbt-bigquery`):** execução produtiva na GCP com particionamento por mês (`revenue_month`), clustering (`account_id`, `plan_tier`) e `maximum_bytes_billed` configurado para controle FinOps.

## Alternativas Consideradas
1. **Apenas BigQuery (dev + CI + prod):** exigiria Service Account/WIF ativa para qualquer pessoa testar o repositório e geraria fricção no onboarding e custo de CI.
2. **Apenas DuckDB local:** não demonstraria práticas reais de Cloud Warehouse (IAM, particionamento BigQuery, Cloud Run Jobs e Terraform).

## Consequências & Trade-offs
- **Positivas:** CI roda `dbt build` completo (snapshots + unit tests + singular tests) em segundos a custo zero; paridade de negócio garantida entre local e nuvem.
- **Negativas / Trade-offs:** exige disciplina para manter SQL ANSI-portável (evitando funções proprietárias desnecessárias ou abstraindo dialetos via macros dbt quando necessário).
