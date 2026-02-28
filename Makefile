MODULE_DIR ?= hello-world-module
MODULES_DIR ?= modules
MODULE_PATH := $(if $(filter $(MODULES_DIR)/%,$(MODULE_DIR)),$(MODULE_DIR),$(MODULES_DIR)/$(MODULE_DIR))
MODULE_ID ?= com.example.mymodule
MODULE_NAME ?= MyModule
MODULE_PACKAGE ?= $(MODULE_ID)
IGNITION_SDK_VERSION ?= 8.1.52
MODULE_LICENSE_MODE ?= free
MODULE_LICENSE ?=

CERT_DIR ?= certs
CERT_NAME ?= module-signing
CERT_CN ?= Ignition Module Dev Signing
CERT_DAYS ?= 825
CERT_PASSWORD ?= changeit

MODULE_SIGNER_JAR ?= tools/module-signer.jar
MODULE_SIGNER_NEXUS_BASE ?= https://nexus.inductiveautomation.com/repository/inductiveautomation-releases
MODULE_SIGNER_GROUP_ID ?= com.inductiveautomation.ignitionsdk
MODULE_SIGNER_ARTIFACT_ID ?= module-signer
MODULE_SIGNER_FALLBACK_URL ?=
KEYSTORE_PATH ?= $(CERT_DIR)/$(CERT_NAME).p12
KEYSTORE_PASSWORD ?= $(CERT_PASSWORD)
KEY_ALIAS ?= modulesign
ALIAS_PASSWORD ?= $(KEYSTORE_PASSWORD)
CERT_CHAIN_PATH ?= $(CERT_DIR)/$(CERT_NAME).chain.p7b
MODULE_IN ?=
MODULE_OUT ?=

.PHONY: help dev-build dev-up dev-shell dev-stop dev-restart scaffold-module module-set-license module-build module-clean gradle-reset cert-help cert-generate signer-download sign-help sign-module verify ps logs-dev logs-gateway gateway gateway-latest gateway-8-1-52 gateway-stop down reset

help:
	@echo "Available targets:"
	@echo "  dev-build       Build dev container image"
	@echo "  dev-up          Start dev container"
	@echo "  dev-shell       Open shell in dev container"
	@echo "  dev-stop        Stop dev container"
	@echo "  dev-restart     Restart dev container"
	@echo "  scaffold-module Generate a new module scaffold"
	@echo "  module-set-license Update moduleLicense in gradle.properties"
	@echo "  module-build    Build module at MODULE_PATH (default: modules/hello-world-module)"
	@echo "  module-clean    Clean module at MODULE_PATH (default: modules/hello-world-module)"
	@echo "  gradle-reset    Remove compose containers and Gradle/Maven cache volumes"
	@echo "  cert-help       Show certificate generation variables"
	@echo "  cert-generate   Generate local signing certificate/keystore assets"
	@echo "  signer-download Download latest IA module-signer jar"
	@echo "  sign-help       Show required signing variables"
	@echo "  sign-module     Sign built module with official module-signer tool"
	@echo "  verify          Verify Java, Gradle, and user context in dev container"
	@echo "  ps              Show compose services status"
	@echo "  logs-dev        Tail dev container logs"
	@echo "  logs-gateway    Tail gateway container logs"
	@echo "  gateway         Start gateway (uses IGNITION_VERSION from env/defaults)"
	@echo "  gateway-latest  Start gateway with IGNITION_VERSION=latest"
	@echo "  gateway-8-1-52  Start gateway with IGNITION_VERSION=8.1.52"
	@echo "  gateway-stop    Stop gateway container"
	@echo "  down            Stop and remove compose services"
	@echo "  reset           Full reset: remove containers, volumes, and local compose images"

dev-build:
	docker compose build dev

dev-up:
	docker compose up -d dev

dev-shell:
	docker compose exec dev bash

dev-stop:
	docker compose stop dev

dev-restart:
	docker compose restart dev

scaffold-module:
	./scripts/scaffold-module.sh "$(MODULE_PATH)" "$(MODULE_ID)" "$(MODULE_NAME)" "$(MODULE_PACKAGE)" "$(IGNITION_SDK_VERSION)"

module-set-license:
	./scripts/set-module-license.sh "$(MODULE_PATH)" "$(MODULE_LICENSE_MODE)" "$(MODULE_LICENSE)"

module-build:
	docker compose exec dev bash -lc 'cd /workspace/$(MODULE_PATH) && gradle clean build'

module-clean:
	docker compose exec dev bash -lc 'cd /workspace/$(MODULE_PATH) && gradle clean'

gradle-reset:
	docker compose --profile gateway down --volumes --remove-orphans

cert-help:
	@echo "Certificate generation vars:"
	@echo "  CERT_DIR        Output directory (default: certs)"
	@echo "  CERT_NAME       Base filename prefix (default: module-signing)"
	@echo "  CERT_CN         Certificate common name"
	@echo "  KEY_ALIAS       Keystore alias (default: modulesign)"
	@echo "  CERT_PASSWORD   Keystore password (default: changeit)"
	@echo "  CERT_DAYS       Validity days (default: 825)"

cert-generate:
	./scripts/generate-signing-cert.sh "$(CERT_DIR)" "$(CERT_NAME)" "$(CERT_CN)" "$(KEY_ALIAS)" "$(CERT_PASSWORD)" "$(CERT_DAYS)"

signer-download:
	MODULE_SIGNER_NEXUS_BASE="$(MODULE_SIGNER_NEXUS_BASE)" MODULE_SIGNER_GROUP_ID="$(MODULE_SIGNER_GROUP_ID)" MODULE_SIGNER_ARTIFACT_ID="$(MODULE_SIGNER_ARTIFACT_ID)" MODULE_SIGNER_FALLBACK_URL="$(MODULE_SIGNER_FALLBACK_URL)" ./scripts/download-module-signer.sh "$(MODULE_SIGNER_JAR)"

sign-help:
	@echo "Required vars for sign-module:"
	@echo "  MODULE_DIR         Module name/path under modules/ (default: hello-world-module)"
	@echo "                     Effective module path: $(MODULE_PATH)"
	@echo "  MODULE_SIGNER_JAR  Path to module-signer jar (default: tools/module-signer.jar)"
	@echo "                     Auto-downloaded if missing from IA Nexus latest metadata."
	@echo "  MODULE_SIGNER_NEXUS_BASE  Nexus releases repo base URL"
	@echo "  MODULE_SIGNER_GROUP_ID    Signer group id (default: com.inductiveautomation.ignitionsdk)"
	@echo "  MODULE_SIGNER_ARTIFACT_ID Signer artifact id (default: module-signer)"
	@echo "  MODULE_SIGNER_FALLBACK_URL Optional direct jar URL fallback"
	@echo "  KEYSTORE_PATH      Path to PKCS12/JKS keystore file (default: certs/module-signing.p12)"
	@echo "  KEYSTORE_PASSWORD  Keystore password (default: changeit)"
	@echo "  KEY_ALIAS          Key alias in the keystore (default: modulesign)"
	@echo "  ALIAS_PASSWORD     Alias/key password (default: KEYSTORE_PASSWORD)"
	@echo "  CERT_CHAIN_PATH    Path to certificate chain (.p7b) (default: certs/module-signing.chain.p7b)"
	@echo "Optional vars:"
	@echo "  MODULE_IN          Explicit input .unsigned.modl path"
	@echo "  MODULE_OUT         Explicit output .signed.modl path"

sign-module:
	@if [ -z "$(KEYSTORE_PASSWORD)" ] || [ -z "$(KEY_ALIAS)" ] || [ -z "$(ALIAS_PASSWORD)" ]; then \
		echo "Missing required signing vars. Run 'make sign-help'."; \
		exit 1; \
	fi
	./scripts/sign-module.sh "$(MODULE_PATH)" "$(MODULE_SIGNER_JAR)" "$(KEYSTORE_PATH)" "$(KEYSTORE_PASSWORD)" "$(KEY_ALIAS)" "$(ALIAS_PASSWORD)" "$(CERT_CHAIN_PATH)" "$(MODULE_IN)" "$(MODULE_OUT)"

verify:
	docker compose exec dev java -version
	docker compose exec dev gradle -v
	docker compose exec dev bash -lc 'id && pwd'

ps:
	docker compose ps

logs-dev:
	docker compose logs -f dev

logs-gateway:
	docker compose --profile gateway logs -f gateway

gateway:
	docker compose --profile gateway up -d gateway

gateway-latest:
	IGNITION_VERSION=latest docker compose --profile gateway up -d gateway

gateway-8-1-52:
	IGNITION_VERSION=8.1.52 docker compose --profile gateway up -d gateway

gateway-stop:
	docker compose --profile gateway stop gateway

down:
	docker compose down

reset:
	docker compose --profile gateway down --volumes --remove-orphans --rmi local
	$(MAKE) gradle-reset
