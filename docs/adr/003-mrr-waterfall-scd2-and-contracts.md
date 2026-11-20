# ADR-003: Modelagem de MRR Waterfall com SCD Type 2, Contratos Enforced e Reconciliação Contábil

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto
Em empresas SaaS B2B, o cálculo de **MRR (Monthly Recurring Revenue)** e **NRR (Net Revenue Retention)** é a métrica mais auditada por diretoria e investidores. Erros comuns incluem:
- Sobrescrever o plano/preço atual do cliente e corromper o MRR histórico;
- Contar duplicatas de faturas ou registros malformados;
- Divergência entre o MRR do mês anterior somado aos movimentos (New, Expansion, Contraction, Churn, Reactivation) e o MRR final do mês.

## Decisão
1. **Write-Audit-Publish (WAP) na Ingestão:** validar contratos de entrada com **Pandera** antes de carregar na camada `raw`, desviando registros corrompidos para uma área de **quarentena** auditável.
2. **SCD Type 2 via `dbt snapshots`:** rastrear o histórico completo de mudanças de plano e preço em `snap_subscriptions`.
3. **Contratos Enforced (`contract: {enforced: true}`) e `access: public` nos Marts:** impedir breaking changes silenciosas de schema para consumidores de BI.
4. **Reconciliação Contábil Automatizada:** aplicar `dbt unit tests` para casos de borda (upgrade, downgrade, churn, reativação) e um teste singular (`assert_mrr_waterfall_reconciles.sql`) garantindo que `beginning_mrr + new_mrr + expansion_mrr + reactivation_mrr - contraction_mrr - churned_mrr == ending_mrr` em 100% dos meses.

## Consequências & Trade-offs
- **Positivas:** auditabilidade nível financeiro, proteção contra regressões de schema e confiança total nos números executivos.
- **Negativas / Trade-offs:** exige atualização explícita do contrato YAML ao alterar colunas nos marts (atrito intencional e saudável para governança).
