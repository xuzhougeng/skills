---
name: sealos-remote-deploy
description: Use when Codex needs to deploy or update a Sealos-hosted Kubernetes app from a local repository and kubeconfig. Covers installing Sealos v5.1.1 and kubectl, discovering namespace-scoped resources, building and pushing Docker images, restarting or updating Deployments, and verifying rollout plus public endpoints.
---

# Sealos Remote Deploy

## Core Rule

Treat the kubeconfig and the app manifest as different files. `sealos apply -f` in Sealos 5.1.1 applies a Sealos Clusterfile, not an arbitrary Kubernetes kubeconfig. When the user gives a kubeconfig such as `/path/to/kubeconfig.yaml`, use `kubectl --kubeconfig <file>` for app resources unless the user also provides an actual Clusterfile or Kubernetes manifest to apply.

## Tool Setup

Prefer the bundled installer:

```bash
bash ~/.codex/skills/sealos-remote-deploy/scripts/ensure-sealos-tools.sh
```

Manual Sealos install, matching the known working version:

```bash
mkdir -p ~/.local/bin
wget https://github.com/labring/sealos/releases/download/v5.1.1/sealos_5.1.1_linux_amd64.tar.gz
tar xf sealos_5.1.1_linux_amd64.tar.gz
mv sealos ~/.local/bin
chmod +x ~/.local/bin/sealos
```

If `kubectl` is missing, install it to `~/.local/bin/kubectl`:

```bash
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
curl -L -o ~/.local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x ~/.local/bin/kubectl
```

Use `~/.local/bin/kubectl` explicitly if the shell `PATH` does not include `~/.local/bin`.

## Deployment Workflow

1. Identify inputs:
   - `KUBECONFIG`, for example `/path/to/kubeconfig.yaml`.
   - `APP`, for example `my-app`.
   - Build context, for example `.` or `app/`.
   - Public URL, if the user gives one.

2. Verify local changes before deployment. Use the repository's standard checks for the selected build context, for example:

```bash
npm test
npm run typecheck
npm run build
```

3. Discover the namespace from kubeconfig and avoid cluster-scope list calls when RBAC is namespace-limited:

```bash
KUBECTL="${KUBECTL:-$HOME/.local/bin/kubectl}"
: "${KUBECONFIG:?set KUBECONFIG to the kubeconfig file path}"
NS="$($KUBECTL --kubeconfig "$KUBECONFIG" config view --minify -o 'jsonpath={..namespace}')"
```

4. Inspect the existing app resource and reuse its image/container names:

```bash
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" get deployment "$APP"
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" describe deployment "$APP"
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" get deployment "$APP" -o 'jsonpath={.spec.template.spec.containers[*].name}{"\n"}'
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" get deployment "$APP" -o 'jsonpath={.spec.template.spec.containers[*].image}{"\n"}'
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" get deployment "$APP" -o 'jsonpath={.spec.template.spec.containers[*].imagePullPolicy}{"\n"}'
```

5. Build and push the image. If the existing Deployment uses `latest` with `imagePullPolicy: Always`, pushing the same tag then restarting is sufficient:

```bash
BUILD_TIME="$(date '+%Y %m %d %H:%M')"
BUILD_CONTEXT="${BUILD_CONTEXT:-.}"
docker build --build-arg BUILD_TIME="$BUILD_TIME" -t "$IMAGE" "$BUILD_CONTEXT"
docker push "$IMAGE"
```

If changing tags, update the Deployment instead:

```bash
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" set image deployment/"$APP" "$CONTAINER=$IMAGE"
```

6. Roll out and wait:

```bash
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" rollout restart deployment "$APP"
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" rollout status deployment "$APP" --timeout=180s
```

7. Verify runtime state:

```bash
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" get pods -l app="$APP" -o wide
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" get pods -l app="$APP" -o 'jsonpath={range .items[*]}{.metadata.name}{" "}{.status.phase}{" "}{.status.containerStatuses[0].imageID}{"\n"}{end}'
```

If a public URL is known, verify HTTP:

```bash
curl -sI "$URL"
curl -s "$URL"
```

## Known Sealos Notes

- `sealos --help` should show Sealos 5.1.1 commands such as `apply`, `run`, `exec`, `scp`, `build`, `push`.
- `sealos apply -f Clusterfile` is for Sealos cluster/app image workflows. Do not pass kubeconfig to it.
- Namespace-limited kubeconfigs may fail on `kubectl get deployments -A`; retry in the namespace from `config view --minify`.
- Kubernetes may warn about auto-generated service account tokens. Treat that as non-blocking if the command succeeds.
- `rollout restart` may emit PodSecurity warnings. Treat them as non-blocking if the Deployment rolls out successfully.

## Generic Docker Deployment Example

```bash
KUBECTL="$HOME/.local/bin/kubectl"
KUBECONFIG=/path/to/kubeconfig.yaml
APP=my-app
BUILD_CONTEXT=/path/to/repo
URL=https://example.com
NS="$($KUBECTL --kubeconfig "$KUBECONFIG" config view --minify -o 'jsonpath={..namespace}')"
IMAGE="$($KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" get deployment "$APP" -o 'jsonpath={.spec.template.spec.containers[0].image}')"

cd "$BUILD_CONTEXT"
npm test
npm run typecheck
npm run build
docker build --build-arg BUILD_TIME="$(date '+%Y %m %d %H:%M')" -t "$IMAGE" .
docker push "$IMAGE"
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" rollout restart deployment "$APP"
$KUBECTL --kubeconfig "$KUBECONFIG" -n "$NS" rollout status deployment "$APP" --timeout=180s
curl -sI "$URL"
```
