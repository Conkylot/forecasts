# Setup checklist (forecasts bot)

Based on Metaculus/metac-bot-template @ bcbd016 (2026-10-30).

## What runs
- `.github/workflows/run_bot_on_tournament.yaml`: every 20 minutes, forecasts new questions in
  the current FutureEval bot tournament and MiniBench, skipping ones already forecast.
- `.github/workflows/review_bot.yaml`: weekly score review, off until the repository variable
  `REVIEW_BOT_ENABLED` is `true`. Read-only, no model spend.
- `.github/workflows/run_bot_on_metaculus_cup.yaml`: manual only (bots win no prizes there).

Nothing runs until this code is pushed to GitHub with Actions enabled and the secrets set.

## Repository secrets (Settings -> Secrets and variables -> Actions)
- `METACULUS_TOKEN` (bot account token: https://www.metaculus.com/futureeval/participate/)
- `OPENROUTER_API_KEY` (https://openrouter.ai/keys)
- optional: `ASKNEWS_CLIENT_ID`, `ASKNEWS_SECRET`

Participation / credits form: https://forms.gle/aQdYMq9Pisrf1v7d8
(credit requests are closed for Fall 2026; reapply before the spring season).

Never commit `.env`; it is git-ignored.

## Rules to respect
- No human in the loop: do not look at open questions and adjust forecasts.
- One prize-eligible bot per person.
- Every forecast needs its reasoning comment (the bot posts these).

## Kill rule
If the bot is not above average in MiniBench after three rounds, stop.
