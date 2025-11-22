# ADR-001: Margin Policy, Buffers, and Kill-Switches (Accepted)

## Status
Accepted (v1). Applies to all paid operations.

## Context
The business requires a **hard minimum 40% gross margin** across paid usage. Pricing is credit-based, with worst-case revenue-per-credit (RPC) from the highest-allowance plan used for guardrails. Providers’ pricing can change, and some usage is variable (tokens/seconds). We need deterministic ceilings and an operational buffer.

## Decision
1. **Margin Floor.** Compute all per-operation ceilings using **worst-case RPC** (currently Max plan, RPC ≈ 0.074988 USD).  
2. **Ceilings.** For each operation:
   - `REVENUE = RPC * CREDITS`
   - `MAX_COGS = REVENUE * (1 - 0.40)`
   - `TARGET_COGS = MAX_COGS * (1 - BUFFER)`, with **BUFFER = 0.20** by default.
3. **Enforcement.**
   - Governor denies jobs if estimated COGS > MAX_COGS or if the user lacks credits/plan entitlement.
   - Credits burn atomically with job creation (race-safe), measured COGS recorded on completion.
4. **Monitoring & Alerts.**
   - Yellow alert if 6h rolling average COGS for any operation > **80%** of MAX_COGS.
   - Red alert if > **90%** for 2+ consecutive hours: auto fallback/disable until back under threshold.
5. **Change Management.**
   - Provider unit prices and usage coefficients live in DB and can be updated without code changes.
   - All changes go to **staging first**; budgets recomputed before production rollout.
6. **Reweighting Credits (Last Resort).** If sustainable COGS cannot be achieved with provider swaps/tuning, reweight credits for the affected operation; communicate changes clearly to users.

## Consequences
- We maintain ≥40% margin across all paid usage even at worst-case RPC.
- We retain agility to change providers/models while staying within budget.
- Additional engineering required for measurement and alerting (planned in Stage 6).

## Alternatives Considered
- Pricing per image instead of credits: simpler, but reduces flexibility to tune economics per operation.
- Using average RPC across plans: risks margin shortfalls when mix shifts to high-allowance subscribers.

## Rollback
If this policy materially harms UX or competitiveness, lower BUFFER to 0.10 temporarily and/or enable cheaper providers; do not change the 40% floor without explicit leadership approval.

— End —
