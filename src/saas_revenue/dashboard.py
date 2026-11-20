"""Executive BI-as-Code Dashboard (Streamlit) reading exclusively from governed dbt marts."""

from __future__ import annotations

import duckdb
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

from saas_revenue.config import get_settings

st.set_page_config(
    page_title="SaaS B2B Revenue Intelligence",
    page_icon="📊",
    layout="wide",
)


@st.cache_data(ttl=60)
def load_marts() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Load governed mart tables from DuckDB."""
    settings = get_settings()
    with duckdb.connect(str(settings.local_duckdb_path), read_only=True) as conn:
        waterfall = conn.execute(
            "SELECT * FROM main_marts.fct_mrr_waterfall ORDER BY revenue_month"
        ).df()
        cohorts = conn.execute(
            "SELECT * FROM main_marts.fct_cohort_retention ORDER BY cohort_month, months_since_signup"
        ).df()
        unit_econ = conn.execute(
            "SELECT * FROM main_marts.fct_unit_economics ORDER BY revenue_month"
        ).df()
    return waterfall, cohorts, unit_econ


def main() -> None:
    st.title("📊 SaaS B2B Revenue Intelligence Platform")
    st.caption(
        "Single Source of Truth powered by dbt Core (Enforced Contracts & SCD2) + DuckDB/BigQuery"
    )

    try:
        waterfall_df, cohorts_df, unit_df = load_marts()
    except Exception as exc:
        st.error(
            f"Não foi possível carregar os marts do DuckDB ({exc}). "
            "Execute `python -m saas_revenue.ingest` e `dbt build` primeiro."
        )
        return

    monthly = (
        waterfall_df.groupby("revenue_month", as_index=False)
        .agg(
            beginning_mrr=("beginning_mrr", "sum"),
            new_mrr=("new_mrr", "sum"),
            expansion_mrr=("expansion_mrr", "sum"),
            reactivation_mrr=("reactivation_mrr", "sum"),
            contraction_mrr=("contraction_mrr", "sum"),
            churned_mrr=("churned_mrr", "sum"),
            ending_mrr=("ending_mrr", "sum"),
        )
        .sort_values("revenue_month")
    )

    latest = monthly.iloc[-1]
    prev = monthly.iloc[-2] if len(monthly) > 1 else latest
    mrr_growth_pct = (
        ((latest["ending_mrr"] / prev["ending_mrr"]) - 1) * 100 if prev["ending_mrr"] else 0.0
    )
    nrr_pct = (
        (
            (
                latest["beginning_mrr"]
                + latest["expansion_mrr"]
                - latest["contraction_mrr"]
                - latest["churned_mrr"]
            )
            / latest["beginning_mrr"]
        )
        * 100
        if latest["beginning_mrr"] > 0
        else 100.0
    )

    latest_unit = unit_df[unit_df["revenue_month"] == unit_df["revenue_month"].max()]
    avg_ltv_cac = float(latest_unit["ltv_to_cac_ratio"].mean()) if not latest_unit.empty else 0.0

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Ending MRR", f"US$ {latest['ending_mrr']:,.0f}", f"{mrr_growth_pct:+.1f}% MoM")
    col2.metric("Annualized Run Rate (ARR)", f"US$ {latest['ending_mrr'] * 12:,.0f}")
    col3.metric("Net Revenue Retention (NRR)", f"{nrr_pct:.1f}%")
    col4.metric("LTV / CAC Ratio", f"{avg_ltv_cac:.2f}x")

    st.divider()

    left, right = st.columns(2)
    with left:
        st.subheader("MRR Waterfall (Último Mês)")
        fig_wf = go.Figure(
            go.Waterfall(
                orientation="v",
                measure=[
                    "absolute",
                    "relative",
                    "relative",
                    "relative",
                    "relative",
                    "relative",
                    "total",
                ],
                x=[
                    "Beginning",
                    "New",
                    "Expansion",
                    "Reactivation",
                    "Contraction",
                    "Churn",
                    "Ending",
                ],
                y=[
                    latest["beginning_mrr"],
                    latest["new_mrr"],
                    latest["expansion_mrr"],
                    latest["reactivation_mrr"],
                    -latest["contraction_mrr"],
                    -latest["churned_mrr"],
                    latest["ending_mrr"],
                ],
                connector={"line": {"color": "#64748b"}},
            )
        )
        fig_wf.update_layout(height=380, margin=dict(l=20, r=20, t=20, b=20))
        st.plotly_chart(fig_wf, use_container_width=True)

    with right:
        st.subheader("Evolução de MRR Mensal")
        fig_trend = px.area(
            monthly,
            x="revenue_month",
            y="ending_mrr",
            labels={"revenue_month": "Mês", "ending_mrr": "MRR (US$)"},
        )
        fig_trend.update_layout(height=380, margin=dict(l=20, r=20, t=20, b=20))
        st.plotly_chart(fig_trend, use_container_width=True)

    st.subheader("Net Dollar Retention (NRR %) por Coorte")
    pivot = cohorts_df.pivot(
        index="cohort_month",
        columns="months_since_signup",
        values="net_dollar_retention_pct",
    )
    fig_cohort = px.imshow(
        pivot,
        text_auto=".0f",
        color_continuous_scale="Tealgrn",
        aspect="auto",
        labels={"x": "Meses desde Aquisição", "y": "Coorte", "color": "NRR (%)"},
    )
    st.plotly_chart(fig_cohort, use_container_width=True)


if __name__ == "__main__":
    main()
