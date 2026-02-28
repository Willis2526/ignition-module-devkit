# Ignition Module Development Container

This project provides a Docker Compose-based development environment for building Ignition modules.

## What you get

- Reproducible JDK 17 build container (`dev` service)
- Gradle preinstalled in the image
- Non-root container user (configurable UID/GID)
- Persistent Gradle and Maven caches
- `make scaffold-module` generator for creating new module scaffolds on demand
- Starter module scaffolds at `example-module/` and `bare-module/`
- `make cert-generate` helper to create local signing cert assets
- `make signer-download` helper to fetch latest IA module-signer jar from IA Nexus
- `make module-set-license` helper to adjust module licensing mode
- Optional Ignition Gateway container for local module testing (`gateway` profile)

## Prerequisites

- Docker Engine + Docker Compose v2

## Files

- `Dockerfile.dev`
- `docker-compose.yml`
- `.env.example`
- `scripts/scaffold-module.sh`
- `scripts/generate-signing-cert.sh`
- `scripts/download-module-signer.sh`
- `scripts/set-module-license.sh`
- `scripts/sign-module.sh`
- `example-module/`
- `bare-module/`

## Quick start

1. Copy environment defaults:

```bash
cp .env.example .env
```

2. On Linux, set your host UID/GID in `.env` to avoid permissions issues:

```bash
UID=$(id -u)
GID=$(id -g)
```

3. Build and start the dev container:

```bash
docker compose build dev
docker compose up -d dev
```

4. Build the default starter module (`example-module`):

```bash
make module-build
```

## Build output

The generated module package (`.modl`) is created under `<module>/build/` for whichever module you build.

## Use your own module instead of starter scaffolds

You can remove a starter scaffold (for example `bare-module`) and regenerate it or create a new one at any time:

```bash
rm -rf bare-module
make scaffold-module MODULE_DIR=bare-module MODULE_ID=com.example.baremodule MODULE_NAME=BareModule
```

Build any module directory with:

```bash
make module-build MODULE_DIR=your-module-folder
```

## Optional gateway for testing

Start only when needed:

```bash
docker compose --profile gateway up -d gateway
```

Gateway endpoints:

- Web UI: `http://localhost:18088`
- Gateway network port: `18000`

Default gateway admin password is set by `GATEWAY_ADMIN_PASSWORD` in `.env`.
Gateway version defaults to `latest`. To pin a specific release, set `IGNITION_VERSION` in `.env` (for example `IGNITION_VERSION=8.1.52`).

Stop gateway:

```bash
docker compose --profile gateway stop gateway
```

## Makefile shortcuts

If you prefer `make` commands, use:

```bash
make help
make dev-build
make dev-up
make dev-shell
make scaffold-module MODULE_DIR=my-module MODULE_ID=com.acme.mymodule MODULE_NAME=MyModule
make module-build
make module-build-example
make module-build-bare
make module-build MODULE_DIR=my-module
make module-set-license MODULE_DIR=my-module MODULE_LICENSE_MODE=trial
make cert-generate
make signer-download
make sign-help
make sign-module MODULE_DIR=my-module
make gateway-latest
make gateway-8-1-52
make gateway-stop
make down
```

- `make help` lists all available targets.
- `make dev-build`, `make dev-up`, `make dev-shell` handle normal dev container flow.
- `make scaffold-module ...` creates a new compile-ready module scaffold.
- `make module-build` compiles the module at `MODULE_DIR` (defaults to `example-module`).
- `make module-build-example` compiles `example-module`.
- `make module-build-bare` compiles `bare-module`.
- `make module-build MODULE_DIR=my-module` compiles your own module folder (must contain a valid Gradle module project).
- `make module-clean MODULE_DIR=my-module` cleans your own module folder.
- `make module-set-license ...` updates `moduleLicense` in `<module>/gradle.properties`.
- `make cert-generate` creates a local self-signed cert + PKCS12 + PKCS7 chain in `certs/`.
- `make signer-download` fetches the latest IA `module-signer.jar` into `tools/` using IA Nexus metadata.
- `make sign-help` shows required signing variables.
- `make sign-module ...` signs a built module using IA's official `module-signer` tool.
- `make verify` checks Java/Gradle/user context in the dev container.
- `make gateway-latest` starts gateway with `IGNITION_VERSION=latest`.
- `make gateway-8-1-52` starts gateway pinned to `8.1.52`.
- `make gateway-stop` stops the gateway container.
- `make down` stops all services.

Scaffold example:

```bash
make scaffold-module \
  MODULE_DIR=my-module \
  MODULE_ID=com.acme.mymodule \
  MODULE_NAME=MyModule \
  MODULE_PACKAGE=com.acme.mymodule \
  IGNITION_SDK_VERSION=8.1.52
```

License mode examples:

```bash
make module-set-license MODULE_DIR=my-module MODULE_LICENSE_MODE=apache
make module-set-license MODULE_DIR=my-module MODULE_LICENSE_MODE=proprietary
make module-set-license MODULE_DIR=my-module MODULE_LICENSE_MODE=trial
make module-set-license MODULE_DIR=my-module MODULE_LICENSE_MODE=custom MODULE_LICENSE='My Commercial License'
```

## Module signing (official tool)

1. Generate local certificate assets (dev/test signing):

```bash
make cert-generate
```

This creates:
- `certs/module-signing.p12`
- `certs/module-signing.chain.p7b`

2. Build your module so an `.unsigned.modl` exists:

```bash
make module-build MODULE_DIR=my-module
```

3. Sign it:

```bash
make sign-module MODULE_DIR=my-module
```

Notes:
- If `tools/module-signer.jar` is missing, `make sign-module` auto-downloads the latest signer from IA Nexus.
- To prefetch the jar explicitly, run `make signer-download`.
- If needed, you can override signer source variables (`MODULE_SIGNER_NEXUS_BASE`, `MODULE_SIGNER_GROUP_ID`, `MODULE_SIGNER_ARTIFACT_ID`, `MODULE_SIGNER_FALLBACK_URL`).
- If `MODULE_IN` is omitted, the newest `*.unsigned.modl` under `<module>/build` is used automatically.
- If `MODULE_OUT` is omitted, output defaults to `<input>.signed.modl`.
- To customize cert generation, run `make cert-help`.
- To inspect signing variable defaults, run `make sign-help`.

## Useful commands

Open a shell in the dev container:

```bash
docker compose exec dev bash
```

Verify Java and Gradle:

```bash
docker compose exec dev java -version
docker compose exec dev gradle -v
```

Stop all running services:

```bash
docker compose down
```

## VS Code usage

You can either:

- Run commands from your host terminal with `docker compose exec ...`, or
- Attach VS Code to the running `dev` container using the Dev Containers extension.

## Notes

- The gateway is configured for developer testing (unsigned module and developer upload flags enabled).
- The gateway image defaults to `inductiveautomation/ignition:latest` unless `IGNITION_VERSION` is set.
