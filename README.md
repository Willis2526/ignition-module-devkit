# Ignition Module Development Container

This project provides a Docker Compose-based development environment for building Ignition modules.

## What you get

- Reproducible JDK 17 build container (`dev` service)
- Gradle preinstalled in the image
- Non-root container user (configurable UID/GID)
- Persistent Gradle and Maven caches
- `make scaffold-module` generator for creating new module scaffolds on demand
- Modules are scaffolded under `modules/` for organization
- `make cert-generate` helper to create local signing cert assets
- `make signer-download` helper to fetch latest IA module-signer jar from IA Nexus
- `make module-set-license` helper to adjust module licensing mode
- Optional Ignition Gateway container for local module testing (`gateway` profile)

## Prerequisites

- Docker Engine + Docker Compose v2

## Recommended workflow (fork + track your module)

1. Fork this repository to your own Git hosting account.
2. Clone your fork locally and create a feature branch.
3. Scaffold your module under `modules/` using the commands below.
4. When you are ready to version your module in your fork, remove `modules/` from `.gitignore`.

Example:

```bash
git clone <your-fork-url>
cd ignition-module-devkit
git checkout -b my-module
sed -i '/^modules\/$/d' .gitignore
git add .gitignore modules/
git commit -m "Track modules in this fork"
```

## Files

- `Dockerfile.dev`
- `docker-compose.yml`
- `.env.example`
- `scripts/scaffold-module.sh`
- `scripts/generate-signing-cert.sh`
- `scripts/download-module-signer.sh`
- `scripts/set-module-license.sh`
- `scripts/sign-module.sh`

## Quick start

1. Copy environment defaults:

```bash
cp .env.example .env
```

2. On Linux, write your host UID/GID values into `.env` to avoid permissions issues:

```bash
sed -i "s/^UID=.*/UID=$(id -u)/" .env
sed -i "s/^GID=.*/GID=$(id -g)/" .env
```

3. Build and start the dev container:

```bash
docker compose build dev
docker compose up -d dev
```

4. Create a hello-world module scaffold:

```bash
make scaffold-module MODULE_DIR=hello-world-module MODULE_ID=com.example.helloworld MODULE_NAME=HelloWorld MODULE_PACKAGE=com.example.helloworld
```

5. Build it:

```bash
make module-build MODULE_DIR=hello-world-module
```

Scaffolds are created under `modules/` (for example `modules/hello-world-module`).
By default, `.gitignore` ignores `modules/` so generated module workspaces stay local.

## Hello World walkthrough: compile, sign, and deploy

1. Create the module scaffold:

```bash
make scaffold-module MODULE_DIR=hello-world-module MODULE_ID=com.example.helloworld MODULE_NAME=HelloWorld MODULE_PACKAGE=com.example.helloworld
```

2. Set license mode to free:

```bash
make module-set-license MODULE_DIR=hello-world-module MODULE_LICENSE_MODE=free
```

3. If you want paid/commercial behavior, switch to a paid-oriented mode:

```bash
make module-set-license MODULE_DIR=hello-world-module MODULE_LICENSE_MODE=proprietary
```

4. Compile the module:

```bash
make module-build MODULE_DIR=hello-world-module
```

Build output (`.modl`) is generated under `modules/hello-world-module/build/`.

5. Generate signing assets and sign:

```bash
make cert-generate
make sign-module MODULE_DIR=hello-world-module
```

The signed artifact is written to `modules/hello-world-module/build/` as `*.signed.modl`.

6. Start a local gateway and deploy:

```bash
docker compose --profile gateway up -d gateway
```

Then open `http://localhost:18088`, sign in, go to `Config -> Modules -> Install or Upgrade`, and upload the `*.signed.modl` file.

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
make module-build MODULE_DIR=my-module
make gradle-reset
make module-set-license MODULE_DIR=my-module MODULE_LICENSE_MODE=free
make cert-generate
make signer-download
make sign-help
make sign-module MODULE_DIR=my-module
make gateway-latest
make gateway-8-1-52
make gateway-stop
make down
make reset
```

- `make help` lists all available targets.
- `make dev-build`, `make dev-up`, `make dev-shell` handle normal dev container flow.
- `make scaffold-module ...` creates a new compile-ready module scaffold.
- `make module-build` compiles the module at `modules/MODULE_DIR` (defaults to `modules/hello-world-module`).
- `make module-build MODULE_DIR=my-module` compiles `modules/my-module` (or pass `MODULE_DIR=modules/my-module`).
- `make module-clean MODULE_DIR=my-module` cleans `modules/my-module`.
- `make gradle-reset` removes compose containers and Gradle/Maven cache volumes.
- `make module-set-license ...` updates `moduleLicense` in `modules/<module>/gradle.properties`.
- `make cert-generate` creates a local self-signed cert + PKCS12 + PKCS7 chain in `certs/`.
- `make signer-download` fetches the latest IA `module-signer.jar` into `tools/` using IA Nexus metadata.
- `make sign-help` shows required signing variables.
- `make sign-module ...` signs a built module using IA's official `module-signer` tool.
- `make verify` checks Java/Gradle/user context in the dev container.
- `make gateway-latest` starts gateway with `IGNITION_VERSION=latest`.
- `make gateway-8-1-52` starts gateway pinned to `8.1.52`.
- `make gateway-stop` stops the gateway container.
- `make down` stops all services.
- `make reset` fully resets compose state (containers, named volumes, local compose-built images) and runs `make gradle-reset`.

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
make module-set-license MODULE_DIR=my-module MODULE_LICENSE_MODE=free
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
- If `MODULE_IN` is omitted, the newest `*.unsigned.modl` under `modules/<module>/build` is used automatically.
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

Full reset (remove containers, volumes, and local compose images):

```bash
docker compose --profile gateway down --volumes --remove-orphans --rmi local
```

## VS Code usage

You can either:

- Run commands from your host terminal with `docker compose exec ...`, or
- Attach VS Code to the running `dev` container using the Dev Containers extension.

## Notes

- The gateway is configured for developer testing (unsigned module and developer upload flags enabled).
- The gateway image defaults to `inductiveautomation/ignition:latest` unless `IGNITION_VERSION` is set.

## Troubleshooting

### `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`

Your user does not have permission to access the Docker daemon socket.

Temporary workaround:

```bash
sudo docker compose build dev
```

Recommended fix (Linux):

```bash
sudo usermod -aG docker $USER
newgrp docker
docker ps
docker compose build dev
```

If `docker ps` still fails after `newgrp docker`, log out and back in (or reboot) and retry.

### `docker: command not found` or `docker compose` fails

Install Docker Engine and Docker Compose v2, then verify:

```bash
docker --version
docker compose version
```

### `Cannot connect to the Docker daemon`

Docker is installed but the daemon is not running.

```bash
sudo systemctl status docker
sudo systemctl start docker
docker ps
```

### `service "dev" is not running` when using `docker compose exec` / `make module-build`

Start the dev container first:

```bash
docker compose up -d dev
docker compose ps
```

### `Failed to load native library 'libnative-platform.so' for Linux amd64`

This is usually a broken/corrupted Gradle native cache inside the Docker volume used by the dev container.

Recover with:

```bash
make gradle-reset
make dev-up
make module-build MODULE_DIR=hello-world-module
```

If it still fails, do a full reset and rebuild:

```bash
make reset
make dev-build
make dev-up
make module-build MODULE_DIR=hello-world-module
```

### Host file ownership/permissions look wrong after container actions (Linux)

Set host UID/GID in `.env`, rebuild, and restart:

```bash
cp .env.example .env
sed -i "s/^UID=.*/UID=$(id -u)/" .env
sed -i "s/^GID=.*/GID=$(id -g)/" .env
docker compose build --no-cache dev
docker compose up -d dev
```

If `.env` already exists, update `UID`/`GID` values instead of appending duplicates.

### Gateway container fails to start because ports are in use

The project maps:
- `18088 -> 8088` (Gateway web UI)
- `18000 -> 8000` (Gateway network port)

Find and stop the conflicting process, or change the host-side ports in `docker-compose.yml`.

### Build fails with low disk space / cache issues

Clean unused Docker data, then rebuild:

```bash
docker system df
docker system prune -f
docker volume prune -f
docker compose build dev
```
