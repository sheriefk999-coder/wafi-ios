#!/usr/bin/env python3
"""A tiny stand-in for the WAFI API on the CI Mac: replays responses recorded from a real server
(ci/fixtures/fixtures.json, written by record_fixtures.py) so UI tests and screenshots are deterministic.

Lookup, most specific first: method+path+query+body+who, then without the body, then method+path+who,
then method+path for anyone. `who` is anon/member/pro, from the bearer token (tokens are in seed.json)."""
import hashlib
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qsl, urlsplit

HERE = Path(__file__).parent / "fixtures"
FIX: dict = {}
WHO: dict = {}


def load():
    FIX.update(json.loads((HERE / "fixtures.json").read_text()))
    seed = json.loads((HERE / "seed.json").read_text())
    WHO.update({seed["member"]: "member", seed["pro"]: "pro"})


def canon_query(q: str) -> str:
    return "&".join(f"{k}={v}" for k, v in sorted(parse_qsl(q, keep_blank_values=True)))


def canon_body(b: bytes) -> str:
    if not b:
        return ""
    try:
        return hashlib.sha1(json.dumps(json.loads(b), sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:12]
    except ValueError:
        return ""


def keys(method, path, query, body, who):
    yield f"{method} {path}?{query}#{body}@{who}"
    yield f"{method} {path}?{query}@{who}"
    yield f"{method} {path}@{who}"
    yield f"{method} {path}?{query}@anon"
    yield f"{method} {path}@anon"
    yield f"{method} {path}@member"
    yield f"{method} {path}@pro"


class H(BaseHTTPRequestHandler):
    def _serve(self):
        u = urlsplit(self.path)
        n = int(self.headers.get("content-length") or 0)
        body = canon_body(self.rfile.read(n) if n else b"")
        tok = (self.headers.get("authorization") or "")[7:]
        who = WHO.get(tok, "anon")
        if u.path in ("/health", "/ready"):
            return self._send(200, {"status": "ok"})
        for k in keys(self.command, u.path, canon_query(u.query), body, who):
            if k in FIX:
                r = FIX[k]
                return self._send(r["status"], r["body"], r.get("headers", {}))
        # anything never recorded: an empty success the app shows as "nothing yet"
        sys.stderr.write(f"MISS {self.command} {self.path} ({who})\n")
        if self.command in ("POST", "PUT", "DELETE"):
            return self._send(200, {})
        return self._send(200, {"items": []})

    do_GET = do_POST = do_PUT = do_DELETE = _serve

    def _send(self, status, body, headers=None):
        data = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    load()
    print(f"mock WAFI API on 127.0.0.1:{port} with {len(FIX)} recorded responses", flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
