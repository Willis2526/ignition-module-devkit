#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 5 ]]; then
  echo "Usage: $0 <module_dir> <module_id> <module_name> [module_package] [ignition_version|latest]" >&2
  echo "Example: $0 my-module com.acme.mymodule MyModule com.acme.mymodule 8.3.3" >&2
  echo "Example: $0 my-module com.acme.mymodule MyModule com.acme.mymodule latest" >&2
  exit 1
fi

module_dir="$1"
module_id="$2"
module_name="$3"
module_package="${4:-$module_id}"
ignition_version="${5:-latest}"
module_project_name="$(basename "$module_dir")"
ignition_sdk_nexus_base="${IGNITION_SDK_NEXUS_BASE:-https://nexus.inductiveautomation.com/repository/public}"
ignition_sdk_group_id="${IGNITION_SDK_GROUP_ID:-com.inductiveautomation.ignitionsdk}"
ignition_sdk_artifact_id="${IGNITION_SDK_ARTIFACT_ID:-ignition-common}"

resolve_latest_ignition_sdk_version() {
  local group_path metadata_url metadata version
  group_path="${ignition_sdk_group_id//./\/}"
  metadata_url="${ignition_sdk_nexus_base%/}/${group_path}/${ignition_sdk_artifact_id}/maven-metadata.xml"
  metadata="$(curl -fsSL "$metadata_url")"

  version="$(printf '%s' "$metadata" | sed -n 's|.*<release>\(.*\)</release>.*|\1|p' | head -n 1)"
  if [[ -z "$version" ]]; then
    version="$(printf '%s' "$metadata" | sed -n 's|.*<latest>\(.*\)</latest>.*|\1|p' | head -n 1)"
  fi
  if [[ -z "$version" ]]; then
    version="$(printf '%s' "$metadata" | sed -n 's|.*<version>\(.*\)</version>.*|\1|p' | tail -n 1)"
  fi
  if [[ -z "$version" ]]; then
    echo "Error: could not resolve latest Ignition SDK version from $metadata_url" >&2
    return 1
  fi

  printf '%s' "$version"
}

if [[ -z "$ignition_version" || "$ignition_version" == "latest" ]]; then
  ignition_version="$(resolve_latest_ignition_sdk_version)"
  echo "Resolved latest Ignition SDK version: $ignition_version"
fi

if [[ -e "$module_dir" ]]; then
  echo "Error: target directory '$module_dir' already exists." >&2
  exit 1
fi

if [[ ! "$module_package" =~ ^[a-zA-Z_][a-zA-Z0-9_.]*$ ]]; then
  echo "Error: module_package '$module_package' is not a valid Java package." >&2
  exit 1
fi

if [[ ! "$module_id" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
  echo "Error: module_id '$module_id' contains invalid characters." >&2
  exit 1
fi

class_prefix="$(echo "$module_name" | tr -cd '[:alnum:]')"
if [[ -z "$class_prefix" ]]; then
  echo "Error: module_name must contain at least one letter or number." >&2
  exit 1
fi

package_path="${module_package//./\/}"
module_desc="Bare-bones Ignition module scaffold for ${module_name}."
module_slug="$(echo "$module_name" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-')"
module_slug="${module_slug#-}"
module_slug="${module_slug%-}"
module_url="https://example.com/${module_slug}"

mkdir -p "$module_dir/common/src/main/java/$package_path/common"
mkdir -p "$module_dir/gateway/src/main/java/$package_path/gateway"

cat > "$module_dir/LICENSE.txt" <<EOF2
Apache-2.0
EOF2

cat > "$module_dir/settings.gradle.kts" <<EOF2
pluginManagement {
    repositories {
        gradlePluginPortal()
        maven {
            url = uri("https://nexus.inductiveautomation.com/repository/public/")
        }
    }
}

rootProject.name = "${module_project_name}"

include(":common")
include(":gateway")
EOF2

cat > "$module_dir/gradle.properties" <<EOF2
ignitionVersion=${ignition_version}
moduleId=${module_id}
moduleName=${module_name}
moduleVersion=0.1.0
moduleDescription=${module_desc}
moduleProjectUrl=${module_url}
moduleLicense=LICENSE.txt
moduleFree=true
EOF2

cat > "$module_dir/build.gradle.kts" <<EOF2
import org.gradle.api.plugins.JavaPluginExtension
import org.gradle.jvm.toolchain.JavaLanguageVersion

plugins {
    id("io.ia.sdk.modl") version "0.5.0"
}

group = "${module_package}"

val ignitionVersion: String by project
val moduleIdProp = providers.gradleProperty("moduleId")
val moduleNameProp = providers.gradleProperty("moduleName")
val moduleVersionProp = providers.gradleProperty("moduleVersion")
val moduleDescriptionProp = providers.gradleProperty("moduleDescription")
val moduleProjectUrlProp = providers.gradleProperty("moduleProjectUrl")
val moduleLicenseProp = providers.gradleProperty("moduleLicense")
val moduleFreeProp = providers.gradleProperty("moduleFree").map { it.toBoolean() }.orElse(true)

allprojects {
    repositories {
        mavenCentral()
        maven {
            url = uri("https://nexus.inductiveautomation.com/repository/public/")
        }
    }
}

subprojects {
    plugins.apply("java-library")
    extensions.configure<JavaPluginExtension> {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(17))
        }
    }
}

ignitionModule {
    name.set(moduleNameProp)
    id.set(moduleIdProp)
    moduleVersion.set(moduleVersionProp)
    this.moduleDescription.set(moduleDescriptionProp)
    requiredIgnitionVersion.set(ignitionVersion)
    freeModule.set(moduleFreeProp)
    license.set(moduleLicenseProp)
    skipModlSigning.set(true)
    metaInfo.put("projectUrl", moduleProjectUrlProp)

    hooks.putAll(
        mapOf(
            "${module_package}.gateway.${class_prefix}GatewayHook" to "G"
        )
    )

    projectScopes.putAll(
        mapOf(
            ":gateway" to "G",
            ":common" to "GC"
        )
    )
}
EOF2

cat > "$module_dir/common/build.gradle.kts" <<EOF2
val ignitionVersion: String by rootProject

dependencies {
    compileOnly("com.inductiveautomation.ignitionsdk:ignition-common:\$ignitionVersion")
}
EOF2

cat > "$module_dir/gateway/build.gradle.kts" <<EOF2
val ignitionVersion: String by rootProject

dependencies {
    implementation(project(":common"))
    compileOnly("com.inductiveautomation.ignitionsdk:gateway-api:\$ignitionVersion")
}
EOF2

cat > "$module_dir/common/src/main/java/$package_path/common/${class_prefix}ModuleInfo.java" <<EOF2
package ${module_package}.common;

public final class ${class_prefix}ModuleInfo {
    public static final String MODULE_ID = "${module_id}";

    private ${class_prefix}ModuleInfo() {
        // Utility class
    }
}
EOF2

cat > "$module_dir/gateway/src/main/java/$package_path/gateway/${class_prefix}GatewayHook.java" <<EOF2
package ${module_package}.gateway;

import com.inductiveautomation.ignition.common.licensing.LicenseState;
import com.inductiveautomation.ignition.gateway.model.AbstractGatewayModuleHook;
import com.inductiveautomation.ignition.gateway.model.GatewayContext;

public class ${class_prefix}GatewayHook extends AbstractGatewayModuleHook {
    private GatewayContext context;

    @Override
    public void setup(GatewayContext context) {
        this.context = context;
    }

    @Override
    public void startup(LicenseState activationState) {
        // No-op
    }

    @Override
    public void shutdown() {
        this.context = null;
    }
}
EOF2

echo "Scaffold created at '$module_dir'"
