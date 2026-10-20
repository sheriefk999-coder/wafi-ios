#!/usr/bin/env python3
"""Records the responses the UI tests need from a running WAFI dev server (the one the Android screenshot
tour uses) into ci/fixtures/fixtures.json, plus the ids/tokens they refer to in ci/fixtures/seed.json.

    python3 ci/record_fixtures.py http://127.0.0.1:8000 /path/to/devserver/seed.json
"""
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlencode

sys.path.insert(0, str(Path(__file__).parent))
from mock_api import canon_body, canon_query  # noqa: E402

BASE, SEED_PATH = sys.argv[1].rstrip("/"), sys.argv[2]
SEED = json.loads(Path(SEED_PATH).read_text())
P = SEED["products"]
TOK = {"anon": None, "member": SEED["member"], "pro": SEED["pro"]}
OUT: dict = {}


def rec(method, path, query=None, body=None, who="anon", country="EG", also_anon=False):
    q = urlencode(query or {})
    url = BASE + path + (("?" + q) if q else "")
    data = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/json")
    req.add_header("X-PR-Country", country)
    req.add_header("X-PR-Device", "ci0recorder0device0001")
    if data:
        req.add_header("Content-Type", "application/json")
    if TOK[who]:
        req.add_header("Authorization", "Bearer " + TOK[who])
    try:
        with urllib.request.urlopen(req) as r:
            status, raw = r.status, r.read()
    except urllib.error.HTTPError as e:
        status, raw = e.code, e.read()
    try:
        payload = json.loads(raw) if raw else {}
    except ValueError:
        payload = {}
    cq, cb = canon_query(q), canon_body(data or b"")
    entry = {"status": status, "body": payload}
    for k in (f"{method} {path}?{cq}#{cb}@{who}", f"{method} {path}?{cq}@{who}"):
        OUT[k] = entry
    OUT.setdefault(f"{method} {path}@{who}", entry)
    if also_anon:
        OUT.setdefault(f"{method} {path}?{cq}@anon", entry)
    print(status, method, path, q[:60], who)


IN = {"in_stock": "true"}
for who in ("anon", "member", "pro"):
    rec("GET", "/app/config", {"platform": "ios"}, who=who)
    rec("GET", "/countries", who=who)
    rec("GET", "/products", {**IN, "limit": 40}, who=who)
    rec("GET", "/stores", who=who)
    rec("GET", "/market", who=who)
    rec("GET", "/deals", {"limit": 12}, who=who)
    rec("GET", "/deals", {"limit": 30}, who=who)
for who in ("member", "pro"):
    rec("GET", "/me", who=who)
    rec("GET", "/me/watchlist", who=who)
    rec("GET", "/me/alerts", who=who)
    rec("GET", "/me/preferences", who=who)
    rec("GET", "/me/market-alerts", who=who)
rec("GET", "/quota")
for days in (7, 30, 90):
    rec("GET", "/market/history", {"days": days})
rec("GET", "/advisor/gold")
for cat in ("phones", "laptops", "audio", "tablets", "cars", "pc_parts", "fashion", "music"):
    rec("GET", "/products", {"category": cat, **IN, "limit": 50})
    rec("GET", "/products/analysis", {"category": cat, **IN})
rec("GET", "/products", {"category": "cars", **IN, "limit": 50, "sort": "price_asc"})
for q in ("آيفون", "سامسونج", "Yamaha", "iPhone"):
    for who in ("anon", "member"):                       # a guest gets sign_in_required when the console says so
        rec("GET", "/products", {"q": q, **IN, "limit": 50}, who=who)
        rec("GET", "/products/analysis", {"q": q, **IN}, who=who)
for key in ("a55", "ip15", "rn13", "mba", "corolla", "strat", "4060", "xm5", "ip15_used", "a55_used"):
    for who in ("anon", "member", "pro"):
        rec("GET", f"/products/{P[key]}", who=who)
rec("GET", "/compare", {"ids": ",".join([P["a55"], P["ip15"], P["rn13"]])}, who="pro", also_anon=True)
rec("POST", "/basket", body={"items": [{"product_id": P[k], "qty": 1} for k in ("a55", "xm5", "ipad")]}, also_anon=True)
rec("POST", "/advisor/phones", body={"priority": "value", "category": "phones", "budget": 15000})
rec("POST", "/advisor/pc", body={"budget": 60000, "use": "gaming_stream", "resolution": "1080p"})
rec("POST", "/advisor/cars", body={"family": "couple", "usage": "mixed", "economy": True, "condition": "any", "budget": 1000000})
rec("POST", "/advisor/fashion", body={"need": "both", "occasion": "casual", "gender": "any", "budget": 2500})
rec("POST", "/pc-builder", body={"budget": 45000, "use": "gaming"})
for msg in ("عايز موبايل في حدود ٢٠ ألف", "الدهب عيار ٢١ بكام", "جمّعلي PC بـ ٦٠ ألف للألعاب", "A phone around EGP 20K"):
    rec("POST", "/assistant", body={"message": msg, "lang": "en" if msg[0].isascii() else "ar"})
rec("GET", "/suggest", {"q": "سام"}, who="member")
for q in ("iPhone 13", "iPhone 1", "iPhone"):
    rec("GET", "/suggest", {"q": q}, who="member")
rec("GET", "/tools/trade-in", {"from_id": P["ip13_used"], "to_id": P["ip15"]}, who="member")
rec("POST", "/advisor/phones", body={"priority": "camera", "category": "phones", "budget": 15000})
# Saudi Arabia, for the country screenshots
rec("GET", "/products", {**IN, "limit": 40}, country="SA")

# the dev server records with its quotas switched off; the apps should show the real free plan
REAL_QUOTAS = {"search": {"limit": 15, "window_hours": 8}, "assistant": {"limit": 5, "window_hours": 24},
               "advisor": {"limit": 3, "window_hours": 24}, "compare_items": 2, "basket_items": 8}
for k, v in OUT.items():
    if k.startswith("GET /app/config") and isinstance(v["body"], dict):
        v["body"]["quotas"] = REAL_QUOTAS

fix = Path(__file__).parent / "fixtures"
(fix / "fixtures.json").write_text(json.dumps(OUT, ensure_ascii=False, indent=0, default=str))
(fix / "seed.json").write_text(json.dumps({"member": SEED["member"], "pro": SEED["pro"], "products": P}, ensure_ascii=False, indent=1))
print(len(OUT), "keys written")
