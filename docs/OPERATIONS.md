# Operations notes

How this bot actually runs, what has gone wrong, and how to check on it. `SETUP.md` covers
first-time setup. This file is what was learned after it. Keep it current: when something here
stops being true, fix or delete the line.

Last updated 2026-11-13.

## What runs, and what starts it

| what | started by | cadence |
|---|---|---|
| `run_bot_on_tournament.yaml`: forecast new FutureEval + MiniBench questions | **an external cron**, see below | every 20 min (:04, :24, :44) |
| `review_bot.yaml`: score resolved forecasts, read-only | GitHub schedule (`REVIEW_BOT_ENABLED=true`) | Mondays 06:00 UTC |
| `smoke.yaml`: one bot-testing-area question, **nothing published** | manual | before merging any change |
| `status.yaml` / `tools/status.py`: token owner, open questions, already-forecast flags | manual | as needed |
| `run_bot_on_metaculus_cup.yaml` | manual only (no bot prizes there) | — |

### Why there is an external trigger

GitHub's own `schedule:` fired only about **every 6 hours** on this repo, even though the
workflow asks for every 20 minutes. Tournament questions can open and close inside that gap.
Since 2026-11-12, a cron job on an always-on host (SSH alias `rumors`) calls the GitHub API
and dispatches the workflow at :04, :24 and :44 past each hour.

- Installer: `deploy/install_trigger_rumors.sh`. Run it from a terminal on the Mac, because it
  reads the token at a hidden prompt. Re-running it replaces the token and the cron line without
  duplicating anything.
- Token: a **fine-grained** GitHub PAT, repository access = this repo only, permissions =
  Actions read and write, nothing else. It is stored on the host in a mode-600 file and never
  passed on a command line.
- The GitHub `schedule:` stays enabled as a fallback. An occasional extra run is harmless:
  the bot skips questions it has already forecast, and the workflow's concurrency group queues
  runs instead of overlapping them.
- Removal: see the comment at the top of the installer.

**The trigger fails silently.** When the token expires or is revoked, every call logs `401`
and nothing alerts. Check it with:

```bash
ssh rumors 'tail ~/.forecasts-trigger/trigger.log'     # every line should end in 204
```

Two other signs that it has stopped: the Actions tab shows only `schedule` runs a few hours
apart, and no `workflow_dispatch` runs. To renew, create a new token with the same scope and
re-run the installer.

## How a forecast is made

`main.py`, class `FallTemplateBot2026`:

1. **Research:** one report per question, from `openrouter/perplexity/sonar-pro`.
2. **Forecasts:** **6 predictions per question, 2 from each of three model families**
   (`FORECASTER_MODELS`: Claude Sonnet 5.5, GPT-5.4, Grok 4.7, all via OpenRouter).
   Diverse model families were the most common trait of prize-winning bots.
3. **Parsing:** `openrouter/openai/gpt-5.4-mini` turns each rationale into a structured
   prediction.
4. **Aggregation:** the framework takes the median. It needs at least half of the predictions
   (3 of 6) to succeed, and drops the ones that failed.
5. **Publishing:** the forecast and a reasoning comment are posted to the **bot account**.

Model ids were checked against OpenRouter's model list on 2026-11-11. The library's defaults
pointed at a model OpenRouter no longer serves, which is why every model is pinned.

## Changes and why (newest first)

- **2026-11-13: each multiple-choice parse is checked against the question's options.** On
  question 46468, one of the six parses came back as only `"Other result"`. Aggregation
  rejected the whole question and nothing was posted until the next run happened to retry
  it. A question that closes between runs would have been lost. Now a mismatched parse is
  retried once, and if it is still wrong only that prediction fails. Look for
  `Parse attempt N ... returned options` warnings in the log.
- **2026-11-13: weekly review workflow enabled** (`REVIEW_BOT_ENABLED=true`). First manual
  run succeeded.
- **2026-11-12: balanced ensemble.** The model rotation used a counter shared across
  questions, so with 5 predictions each question got an uneven 2/2/1 split, and the model left
  with one prediction changed from question to question. The median therefore leaned on an
  arbitrary pair of model families. The rotation now restarts for each question, keyed by URL
  plus question text because a conditional's sub-questions share one URL, and 6 predictions
  give exactly 2 per model. That costs about 20 % more per question.
  **Keep `predictions_per_research_report` a multiple of `len(FORECASTER_MODELS)`.**
- **2026-11-12: external 20-minute trigger** (above).
- **2026-11-11: ensemble across three model families; models pinned; smoke mode added.**

## How to change the bot safely

1. Work on a branch. `main` is what the 20-minute trigger runs.
2. Push the branch and run the smoke test on it:
   `gh workflow run smoke.yaml --ref <branch>`. It forecasts one bot-testing-area question
   and publishes nothing. Check the run page's "Smoke result" notice: there should be 2
   forecasts per model and `Errors: []`.
3. The smoke question is whichever bot-testing-area question is first in the list
   (numeric on 2026-11-12/13). It does **not** exercise every question type. Test logic for
   other types locally with the model calls stubbed out, which costs nothing.
4. Fast-forward `main` and delete the branch.

Never run `python main.py` locally in tournament mode just to test. It spends credits and
publishes forecasts.

## Where to see results

- **The bot's forecasts are on the bot account, not your own.** On Metaculus, go to Settings →
  My Forecasting Bots → *Switch to bot account*, then open a question. The forecast is on the
  graph and the reasoning is in the **Private** comments tab.
- **Scores and the leaderboard appear only after questions resolve.** Until then the
  tournament leaderboard has no entry for the bot. That is expected, not a fault.
- **Weekly report:** Actions → *Review recent forecasts* → a run → Artifacts → `review`
  (`review.md` + `review.json`).
- **Locally, read-only, no spend:**

  ```bash
  uv run --env-file .env python tools/status.py
  uv run --env-file .env --group integrations bot-review review --tournament 33121 \
      --output review.json --summary review.md
  ```

State on 2026-11-13: 5 questions forecast (46355, 46466, 46467, 46468, 46469), 0 resolved,
0 scored. Over the first 70 tournament runs, 69 succeeded and 1 failed (the 46468 parse,
since fixed).

## Next steps

1. **Wait for about 10–20 resolved questions, then review** with the `review-bot` skill
   (`.claude/skills/review-bot/SKILL.md`). It is read-only. Find out whether points are
   being lost in research, in the forecasts, or in aggregation, and change only what that
   evidence points at.
2. **Until then, do not** swap models, add research sources or rewrite prompts. With nothing
   resolved there is nothing to measure a change against.
3. **Don't backtest on old resolved questions.** The models may already know the outcomes. If
   faster evidence is needed, `integrations/main_lightningrod_eval.py` generates questions from
   recent news. It needs a LightningRod account and spends OpenRouter credit.
4. Kill rule (`SETUP.md`): if the bot is not above average in MiniBench after three rounds,
   stop.
