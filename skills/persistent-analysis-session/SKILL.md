---
name: persistent-analysis-session
description: Use when exploratory R or Python analysis repeatedly reloads large in-memory objects, such as Seurat, AnnData, model, pickle, RDS, qs, h5ad, joblib, parquet, or other expensive datasets.
---

# Persistent Analysis Session

## Core Rule

When a large object is expensive to load, do not run analysis scripts as fresh one-shot processes. Create or reuse a localhost persistent session that loads the object once, then send small analysis scripts to that session.

This is for exploratory work. Keep production pipelines, reproducible batch jobs, and CI scripts as normal process-per-run commands unless the user asks otherwise.

## Workflow

1. Identify the language, large object path, loader, and desired in-session object name.
2. Check for existing project policy files (`AGENTS.md`, `Makefile`, `tools/`, `analysis/`) before adding new tooling.
3. Add a local server from `scripts/r_session_server.R` or `scripts/python_session_server.py`, adapting only the loader defaults and dependency imports.
4. Add `Makefile` targets like `session-server` and `session-run`, bound to `127.0.0.1`.
5. Put analysis code under `analysis/`. The analysis script must assume the large object already exists in memory and must not reload it.
6. Verify with a skip-load or tiny fixture mode before loading the real large object.

## Safety

- Bind only to `127.0.0.1`; never use `0.0.0.0` unless the user explicitly accepts the risk.
- Treat `/run` as arbitrary code execution. Do not expose it to a network.
- Do not kill a user-owned long-running session unless asked.
- If the object is huge, verify syntax and endpoint behavior with a mock or skip-load mode first.

## R Pattern

Use the R template when files are loaded with `qs::qread()`, `readRDS()`, Seurat, Monocle, CellChat, WGCNA, or similar R workflows.

Read `references/r.md` only when implementing or adapting the R server.

Expected project commands:

```makefile
session-server:
	R_SESSION_OBJECT_PATH="$(OBJECT_PATH)" R_SESSION_OBJECT_NAME="$(OBJECT_NAME)" Rscript tools/r_session_server.R

session-run:
	curl -sS --data-binary @"$(FILE)" http://127.0.0.1:8787/run
```

## Python Pattern

Use the Python template when files are loaded with `scanpy.read_h5ad()`, `anndata.read_h5ad()`, `pickle`, `joblib`, pandas, xarray, torch, or similar Python workflows.

Read `references/python.md` only when implementing or adapting the Python server.

Expected project commands:

```makefile
session-server:
	PY_SESSION_OBJECT_PATH="$(OBJECT_PATH)" PY_SESSION_OBJECT_NAME="$(OBJECT_NAME)" python tools/python_session_server.py

session-run:
	curl -sS --data-binary @"$(FILE)" http://127.0.0.1:8787/run
```

## Common Mistakes

- Reintroducing `readRDS()`, `qread()`, `read_h5ad()`, `pickle.load()`, or `joblib.load()` inside every analysis script.
- Starting the server with the default large object just to test plumbing. Use skip-load or a tiny fixture first.
- Writing project-specific data paths into the reusable skill. Keep paths configurable.
- Forgetting that Codex resume preserves conversation state, not R or Python process memory.
