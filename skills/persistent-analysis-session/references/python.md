# Python Persistent Session Reference

Copy `scripts/python_session_server.py` into `tools/python_session_server.py`, then adapt loader defaults and optional imports.

## Environment Variables

- `PY_SESSION_OBJECT_PATH`: object file path, default `data/object.pkl`
- `PY_SESSION_OBJECT_NAME`: name assigned in the session, default `obj`
- `PY_SESSION_HOST`: default `127.0.0.1`
- `PY_SESSION_PORT`: default `8787`
- `PY_SESSION_SKIP_LOAD`: set to `1` for endpoint tests without loading the object
- `PY_SESSION_LOADER`: optional explicit loader: `auto`, `pickle`, `joblib`, `h5ad`, `csv`, `parquet`

## Loader Rules

- `.pkl`, `.pickle` -> `pickle.load()`
- `.joblib` -> `joblib.load()`
- `.h5ad` -> `scanpy.read_h5ad()` or `anndata.read_h5ad()`
- `.csv` -> `pandas.read_csv()`
- `.parquet` -> `pandas.read_parquet()`

If a dependency is missing, report it and either install with approval or adapt the loader.

## Analysis Script Style

Good:

```python
print(type(obj))
print(getattr(obj, "shape", None))
```

Bad:

```python
import pickle
with open("data/object.pkl", "rb") as handle:
    obj = pickle.load(handle)
```

The analysis script should use the configured object name directly.
