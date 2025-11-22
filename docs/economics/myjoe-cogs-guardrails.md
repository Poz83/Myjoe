# My Joe – COGS Guardrails & Margin Policy (v1)

**Purpose.** Lock production-grade, spreadsheet-ready rules that guarantee a **minimum 40% gross margin** on paid usage while allowing easy provider/model swaps. This document defines formulas, target budgets, buffers, monitoring, and run-time enforcement hooks.

---

## 1) Definitions & plan inputs

Plans (current example pricing):
- Lite: **$9.99 / 115 credits**
- Pro: **$29.99 / 375 credits**
- Max: **$59.99 / 800 credits**

Revenue per credit (RPC) per plan:
- Lite RPC = 9.99 / 115 = **0.086870 USD**
- Pro RPC = 29.99 / 375 = **0.079973 USD**
- Max RPC = 59.99 / 800 = **0.074988 USD**  ← **worst-case baseline**

**Always** size guardrails with **worst-case RPC** (Max plan) to maintain the minimum 40% margin across all paid usage.

Credit weights (v1):
- Raster generation: **1 credit**
- Vector generation: **2 credits**
- Fix/Upscale: **0.5 credits**

---

## 2) Formulas (use these in Excel/Sheets)

Let:
- `RPC` = worst-case revenue per credit (currently 0.074988),
- `CREDITS` = credits per operation,
- `MARGIN_MIN` = 0.40 (40%),
- `BUFFER` = default **0.20** (20% volatility buffer).

Then:
- **Revenue per operation**: `REVENUE = RPC * CREDITS`
- **Max COGS** (exactly at min margin):  
  `MAX_COGS = REVENUE * (1 - MARGIN_MIN)`
- **Target COGS** (apply buffer for real-world volatility):  
  `TARGET_COGS = MAX_COGS * (1 - BUFFER)`

Recommended default: `BUFFER = 0.20` (raise to 0.30 for volatile vendors).

---

## 3) Derived budgets (using RPC = 0.074988)

| Operation      | Credits | Revenue/op (USD) | Max COGS (USD) | Target COGS (USD, 20% buffer) |
|----------------|---------|------------------:|----------------:|-------------------------------:|
| Raster         | 1.0     | 0.074988         | 0.044993        | 0.035994                       |
| Vector         | 2.0     | 0.149975         | 0.089985        | 0.071988                       |
| Fix/Upscale    | 0.5     | 0.037494         | 0.022496        | 0.017997                       |

Round to 3–4 decimals for display; store full precision for calculations.

---

## 4) Budget split by pipeline step (starting guidance)

**Raster (1 credit, target ≈ $0.035994):**
- LLM “Brain” prompt-to-manifest: **≤ $0.0035**
- Raster model (Bulk/Hero) **core render**: **≤ $0.0280**
- QC/Judge + light upscaler (if auto-applied): **≤ $0.0045**
- Total ≤ **$0.035994**

**Fix/Upscale (0.5 credit, target ≈ $0.017997):**
- Upscaler: **≤ $0.0150**
- Judge/QC: **≤ $0.0030**
- Total ≤ **$0.017997**

**Vector (2 credits, target ≈ $0.071988):**
- Vectorisation/binarisation pipeline (e.g. deterministic + cleanup): **≤ $0.0500**
- LLM overhead (style/repair hints, if any): **≤ $0.0040**
- QC/Judge pass: **≤ $0.0050**
- Headroom for contingencies: **≈ $0.0129**

> Notes:
> - These splits are **policy suggestions**, not hard enforcement; the **operation-level TARGET_COGS** is the true gate.
> - Keep LLM prompts tightly structured (JSON schema) to control token costs.

---

## 5) Monitoring & alerts (measured COGS)

You will log measured COGS per operation and per provider. Minimum suggested metrics captured per job:
- `user_id`, `operation_type`, `job_id`, `project_id`
- `provider` + `model_version`
- **Estimated/charged cost in USD** (per vendor’s usage model)
- Tokens, seconds, or images used (provider-specific usage units)
- Timestamps (`started_at`, `completed_at`)
- `success` / `failure_reason`

**Alerts (rolling windows):**
- **Yellow:** 6-hour weighted average COGS for any operation > **80%** of `MAX_COGS`.
- **Red:** 6-hour weighted average COGS for any operation > **90%** of `MAX_COGS` → auto-apply **kill-switch** or **fallback provider** until cleared.

---

## 6) Run-time enforcement (Governor pre-check)

Before enqueuing a job, compute `ESTIMATED_COGS` using the latest provider price table + usage coefficients (kept in DB). Deny if:
- **Insufficient credits**, or
- `ESTIMATED_COGS > MAX_COGS` for the requested operation, or
- Plan doesn’t permit the feature (e.g., Lite attempting vector).

If the job proceeds, **burn credits atomically** with job creation (details in Stage 6 – Ledger & Governor). On completion, record **measured** COGS and compare to estimate.

---

## 7) Volatility & buffers

- Default **20% buffer** (TARGET = 80% of MAX_COGS).  
- For providers with rapid price swings or uncertain unit usage, temporarily raise to **30%**.
- Track **effective buffer** daily: `(MAX_COGS - AVG_MEASURED_COGS) / MAX_COGS`.

**Stop-ship rule:** If AVG_MEASURED_COGS for any operation exceeds **90%** of MAX_COGS for > 2 consecutive hours, disable the riskiest sub-step or force a fallback model until green.

---

## 8) Trial cost envelope

Trials are watermarked and credit-capped (~10 images). Keep average **trial raster** COGS ≤ **$0.030** by:
- Preferring **Bulk** model,
- Reducing default resolution for trials,
- Skipping optional QC passes unless necessary to enforce 1-bit constraints.

---

## 9) Change procedure

1) Update provider unit-prices & usage coefficients in DB (staging first).  
2) Recompute budgets in the sheet; confirm TARGET_COGS margins.  
3) If any TARGET_COGS is violated, either:
   - switch to a cheaper provider/model,
   - tune prompts/resolution,
   - or **reweight credits** (as a last resort).  
4) Ship changes behind a feature flag; observe measured COGS for 24h.

---

## 10) Next steps (later stages)

- Stage 6 will add the **append-only credit ledger**, Governor function, and **cost_events** table, plus scheduled reports (daily COGS vs MAX/TARGET).
- Worker will emit **provider-specific usage** (seconds, tokens) to support precise measurement.

— End —
