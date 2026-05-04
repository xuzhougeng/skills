#!/usr/bin/env python3
import contextlib
import io
import json
import os
import pickle
import sys
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


OBJECT_PATH = os.environ.get("PY_SESSION_OBJECT_PATH", "data/object.pkl")
OBJECT_NAME = os.environ.get("PY_SESSION_OBJECT_NAME", "obj")
HOST = os.environ.get("PY_SESSION_HOST", "127.0.0.1")
PORT = int(os.environ.get("PY_SESSION_PORT", "8787"))
SKIP_LOAD = os.environ.get("PY_SESSION_SKIP_LOAD", "0") == "1"
LOADER = os.environ.get("PY_SESSION_LOADER", "auto")

SESSION_GLOBALS = {
    "__name__": "__persistent_analysis_session__",
    "__builtins__": __builtins__,
}


def load_object(path_string, loader):
    path = Path(path_string)
    selected = loader
    if selected == "auto":
        selected = path.suffix.lower().lstrip(".")

    if selected in {"pkl", "pickle"}:
        with path.open("rb") as handle:
            return pickle.load(handle)

    if selected == "joblib":
        import joblib

        return joblib.load(path)

    if selected == "h5ad":
        try:
            import scanpy as sc

            return sc.read_h5ad(path)
        except ImportError:
            import anndata as ad

            return ad.read_h5ad(path)

    if selected == "csv":
        import pandas as pd

        return pd.read_csv(path)

    if selected == "parquet":
        import pandas as pd

        return pd.read_parquet(path)

    raise ValueError(f"unsupported loader '{loader}' for {path}; set PY_SESSION_LOADER or edit load_object()")


if SKIP_LOAD:
    print("Skipping object load because PY_SESSION_SKIP_LOAD=1", file=sys.stderr)
else:
    object_path = Path(OBJECT_PATH)
    if not object_path.exists():
        raise FileNotFoundError(f"object file not found: {OBJECT_PATH}")
    print(f"Loading object once from {OBJECT_PATH} ...", file=sys.stderr)
    SESSION_GLOBALS[OBJECT_NAME] = load_object(OBJECT_PATH, LOADER)
    print(f"Loaded object as: {OBJECT_NAME}", file=sys.stderr)


SESSION_GLOBALS["_persistent_session"] = {
    "object_path": OBJECT_PATH,
    "object_name": OBJECT_NAME,
    "loaded": not SKIP_LOAD,
}


def status_payload():
    return {
        "ok": True,
        "object_path": OBJECT_PATH,
        "object_name": OBJECT_NAME,
        "loaded": not SKIP_LOAD,
        "objects": sorted(k for k in SESSION_GLOBALS if not k.startswith("__")),
    }


def run_code(code):
    stdout = io.StringIO()
    stderr = io.StringIO()
    try:
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            exec(compile(code, "<persistent-session>", "exec"), SESSION_GLOBALS)
        return {
            "ok": True,
            "output": stdout.getvalue(),
            "messages": stderr.getvalue(),
            "error": None,
        }
    except Exception as exc:
        return {
            "ok": False,
            "output": stdout.getvalue(),
            "messages": stderr.getvalue(),
            "error": str(exc),
            "traceback": traceback.format_exc(),
        }


class Handler(BaseHTTPRequestHandler):
    def _json(self, payload, status=200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/status":
            self._json(status_payload())
            return
        self._json({"ok": False, "error": "not found"}, status=404)

    def do_POST(self):
        if self.path != "/run":
            self._json({"ok": False, "error": "not found"}, status=404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        code = self.rfile.read(length).decode("utf-8")
        payload = run_code(code)
        self._json(payload, status=200 if payload["ok"] else 400)

    def log_message(self, format, *args):
        return


def main():
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Persistent Python session listening on http://{HOST}:{PORT}", file=sys.stderr)
    server.serve_forever()


if __name__ == "__main__":
    main()
