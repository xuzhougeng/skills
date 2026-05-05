# R Persistent Session Reference

Copy `scripts/r_session_server.R` into `tools/r_session_server.R`, then adapt only defaults and package imports.

## Environment Variables

- `R_SESSION_OBJECT_PATH`: object file path, default `data/object.qs`
- `R_SESSION_OBJECT_NAME`: name assigned in the session, default `obj`
- `R_SESSION_HOST`: default `127.0.0.1`
- `R_SESSION_PORT`: default `8787`
- `R_SESSION_SKIP_LOAD`: set to `1` for endpoint tests without loading the object

## Windows Background Use

Use the same server script on Windows. Start it with PowerShell `Start-Process`, set `$env:R_SESSION_*` variables first, and submit `/run` requests with `Invoke-RestMethod`. See `windows.md` for concrete commands.

## Loader Rules

- `.qs` -> `qs::qread(path)`
- `.rds` -> `readRDS(path)`
- Other formats require an explicit project-specific loader added near `load_object()`.

## Analysis Script Style

Good:

```r
print(class(obj))
dir.create("results", showWarnings = FALSE)
```

Bad:

```r
obj <- qs::qread("data/object.qs")
```

The analysis script should use the configured object name directly.
