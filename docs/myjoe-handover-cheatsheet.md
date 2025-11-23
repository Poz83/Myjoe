# My Joe – Smart Handover Cheat Sheet

This cheat sheet is for **me (Jamie)** and **any ChatGPT instance** working on My Joe.

It defines the **exact phrases** I will use to trigger a **Smart Handover**, so new chats always know:

- What we’ve done,
- How we did it,
- What stage we’re on,
- What to do next.

All assistants working on My Joe must treat these phrases as **strong signals** to stop normal work and generate/update the Smart Handover Prompt.

---

## When to trigger a Smart Handover

Use a Smart Handover in three main situations:

1. **End of a stage**  
   When a stage (Stage 0, Stage 1, etc.) is finished and I’m ready to move on.

2. **Mid-stage snapshot / early exit**  
   When I need to stop partway through a stage (tired, out of time, big change, etc.) and want a clean checkpoint.

3. **Manual or emergency handover**  
   When things feel messy or I want a fresh chat to take over with a clean summary.

---

## Primary trigger phrases

The assistant must respond to these phrases by generating the **Smart Handover Prompt** for the **next chat**.

### 1. End of stage (preferred)

**Exact phrase:**

> Stage X complete — run the Smart Handover now.

Examples:

- Stage 0 complete — run the Smart Handover now.
- Stage 1 complete — run the Smart Handover now.

Short form (also valid):

> Stage X complete.

On hearing either of these, the assistant must:

1. Stop normal work.
2. Confirm which stage has just been completed.
3. Generate the full **Smart Handover Prompt** for the **next stage**, including:
   - What has been done in each stage so far.
   - How it was done (key files/scripts/decisions).
   - Current architecture/stack choices that are “locked in”.
   - Remaining stages and what the next stage must do.
   - Pro vs Extended mode guidance for the next stage.

### 2. Mid-stage snapshot / early stop

If I want to stop in the middle of a stage and hand over the current state, I will say:

> new chat

Or, more explicitly:

> new chat — run the Smart Handover now for the current stage.

On hearing this, the assistant must:

1. Treat the **current** stage as “in progress”.
2. Generate a Smart Handover Prompt that clearly shows:
   - Which stages are done.
   - Which stage is currently in progress.
   - What has already been done in this stage.
   - What remains to be done in this stage.
3. Set the **next chat’s responsibility** as:
   - “Continue Stage X from where we left off.”

### 3. Manual / emergency handover

If I’m unsure what to say but want a handover, I can use:

> Generate a Smart Handover for the current stage now.

The assistant must treat this as an immediate request to produce the Smart Handover Prompt with the best available information.

---

## What the Smart Handover Prompt must contain

Every Smart Handover Prompt must be a **single, copy-pasteable prompt** that works as the **first message** in a new chat.

It should follow this structure:

1. **Project Name & One-line Summary**  
   - “My Joe Image Creator – AI-powered KDP-safe colouring book factory.”

2. **Working Contract (Short Version)**  
   - My environment: Windows 11, PowerShell, repo at `C:\myjoe\myjoe-app`.  
   - Stack: Next.js 14 (App Router), TypeScript, Tailwind, Supabase, Stripe, Python worker, AI models.  
   - File rules: full-file updates, no partial diffs, PowerShell scripts for file creation.  
   - Quality: production-grade, 1-bit colouring art, no steampunk.  
   - Explanation vs PowerShell separation.

3. **Stages Overview & Current Stage**  
   - List all stages (0, 1, 2, …) with statuses: `done / in progress / not started`.  
   - Clearly state: “This new chat is responsible for Stage X.”

4. **What Has Been Done So Far (By Stage)**  
   - For each completed stage:
     - What was done,  
     - How it was done (tools, patterns, key decisions),  
     - Any important caveats or TODOs.

5. **Files and Paths Touched**  
   - List key files/folders relative to `C:\myjoe\myjoe-app`, e.g.:
     - `docs/myjoe-system-blueprint-vX.Y.md` – system blueprint  
     - `docs/adr/ADR-001-...md` – ADRs  
     - `scripts/Preflight-MyJoe.ps1` – environment check  
     - `scripts/Snapshot-BuildState.ps1` – snapshot  
     - `worker/chef.py` – Python worker  
     - `src/app/...`, `src/features/...`, `src/shared/lib/...` etc.

6. **Outstanding Issues / Risks / TODOs**  
   - Distinguish between:
     - `must-fix before launch`, and  
     - `nice-to-have / later`.

7. **Next Stage: Objectives & Boundaries**  
   - What the next stage must achieve.  
   - What is in scope vs out of scope.  
   - Any dependencies or constraints from previous stages or research.

8. **Mode Guidance (Pro vs Extended)**  
   - For the next stage, explicitly state:
     - “Pro / research-heavy – Pro mode recommended,” or  
     - “Implementation-focused – Extended-thinking mode is fine.”  
   - Call out any specific steps within the stage that definitely need Pro.

9. **Instructions for the New Chat**  
   - Tell the next chat to:
     - Read the prompt fully.  
     - Acknowledge once it’s absorbed (e.g. “Ready mate”).  
     - Summarise its understanding:
       - What My Joe is,  
       - Which stage it owns,  
       - What it plans to do first.

---

## Quick reference (for me)

- End of stage:  
  - Stage X complete — run the Smart Handover now.  
- Mid-stage stop:  
  - new chat  
- Emergency / manual:  
  - Generate a Smart Handover for the current stage now.

Any assistant working on My Joe must treat these phrases as non-optional instructions to **generate or update** the Smart Handover Prompt before continuing.
