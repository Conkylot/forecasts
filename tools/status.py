"""Read-only status check: who the token belongs to, and which tournament questions are
open and whether this bot has already forecast them. Makes no forecasts, spends nothing."""
import os
import requests
from forecasting_tools import MetaculusClient

token = os.environ["METACULUS_TOKEN"]
r = requests.get(
    "https://www.metaculus.com/api/users/me/",
    headers={"Authorization": f"Token {token}"},
    timeout=30,
)
print(f"users/me HTTP {r.status_code}")
if r.ok:
    me = r.json()
    print("account:", {k: me.get(k) for k in ("id", "username", "is_bot")})

client = MetaculusClient()
for label, tid in (
    ("seasonal", client.CURRENT_AI_COMPETITION_ID),
    ("minibench", client.CURRENT_MINIBENCH_ID),
):
    try:
        qs = client.get_all_open_questions_from_tournament(tid)
    except Exception as e:  # noqa: BLE001
        print(f"{label} ({tid}): ERROR {type(e).__name__}: {str(e)[:200]}")
        continue
    done = [q for q in qs if getattr(q, "already_forecasted", False)]
    print(f"{label} ({tid}): open={len(qs)} already_forecast_by_this_bot={len(done)}")
    for q in qs[:12]:
        print(
            f"  - {q.page_url} | forecast={getattr(q, 'already_forecasted', None)}"
            f" | closes={getattr(q, 'close_time', None)}"
        )
