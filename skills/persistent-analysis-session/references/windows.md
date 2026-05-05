# Windows PowerShell Reference

Use this reference when the target project runs the persistent R or Python session from Windows PowerShell instead of macOS/Linux shells.

## Rules

- Keep the server bound to `127.0.0.1`.
- Prefer `Start-Process -PassThru` over `Start-Job` for a long-running local server.
- Set environment variables with `$env:NAME = "value"` before `Start-Process`; the child process inherits them.
- Redirect stdout/stderr into `logs/` and store the returned PID when the session is intentionally backgrounded.
- Prefer `Invoke-RestMethod` for `/status` and `/run`; `curl` may be a PowerShell alias.
- Use `*_SESSION_SKIP_LOAD=1` only for plumbing checks; remove it or set it to `0` for the real object load.

## Python Background Server

```powershell
New-Item -ItemType Directory -Force logs | Out-Null

$env:PY_SESSION_OBJECT_PATH = "data\object.pkl"
$env:PY_SESSION_OBJECT_NAME = "obj"
$env:PY_SESSION_HOST = "127.0.0.1"
$env:PY_SESSION_PORT = "8787"
$env:PY_SESSION_SKIP_LOAD = "1"

$p = Start-Process `
  -FilePath "python" `
  -ArgumentList "tools\python_session_server.py" `
  -WorkingDirectory (Get-Location) `
  -RedirectStandardOutput "logs\python-session.out.log" `
  -RedirectStandardError "logs\python-session.err.log" `
  -WindowStyle Hidden `
  -PassThru

$p.Id | Set-Content "logs\python-session.pid"
```

If `python` is not on `PATH`, use the project interpreter path, or use the launcher:

```powershell
Start-Process -FilePath "py" -ArgumentList "-3", "tools\python_session_server.py" -PassThru
```

## R Background Server

```powershell
New-Item -ItemType Directory -Force logs | Out-Null

$env:R_SESSION_OBJECT_PATH = "data\object.qs"
$env:R_SESSION_OBJECT_NAME = "obj"
$env:R_SESSION_HOST = "127.0.0.1"
$env:R_SESSION_PORT = "8787"
$env:R_SESSION_SKIP_LOAD = "1"

$p = Start-Process `
  -FilePath "Rscript" `
  -ArgumentList "tools\r_session_server.R" `
  -WorkingDirectory (Get-Location) `
  -RedirectStandardOutput "logs\r-session.out.log" `
  -RedirectStandardError "logs\r-session.err.log" `
  -WindowStyle Hidden `
  -PassThru

$p.Id | Set-Content "logs\r-session.pid"
```

If `Rscript` is not on `PATH`, use the full `Rscript.exe` path from the project R installation.

## Status and Run

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8787/status"
```

```powershell
$code = Get-Content -Raw -Path "analysis\exploratory_step_01.py"
Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:8787/run" `
  -Body $code `
  -ContentType "text/plain; charset=utf-8"
```

Use the same `/run` command for R by pointing `Get-Content` at an `.R` script.

## Stop When Asked

Do not stop a user-owned session unless the user asks. When they do ask, stop the PID recorded by the launcher:

```powershell
Stop-Process -Id ([int](Get-Content "logs\python-session.pid"))
```

Use the R PID file when stopping an R session.
