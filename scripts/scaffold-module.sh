#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 5 ]]; then
  echo "Usage: $0 <module_dir> <module_id> <module_name> [module_package] [ignition_version]" >&2
  echo "Example: $0 my-module com.acme.mymodule MyModule com.acme.mymodule 8.1.52" >&2
  exit 1
fi

module_dir="$1"
module_id="$2"
module_name="$3"
module_package="${4:-$module_id}"
ignition_version="${5:-8.1.52}"

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

cat > "$module_dir/settings.gradle.kts" <<EOF2
rootProject.name = "${module_dir}"

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
moduleLicense=Apache-2.0
EOF2

cat > "$module_dir/build.gradle.kts" <<EOF2
plugins {
    id("io.ia.sdk.modl") version "0.5.0"
}

group = "${module_package}"

val ignitionVersion: String by project
val moduleId: String by project
val moduleName: String by project
val moduleVersion: String by project
val moduleDescription: String by project
val moduleProjectUrl: String by project
val moduleLicense: String by project

allprojects {
    repositories {
        mavenCentral()
        maven {
            url = uri("https://nexus.inductiveautomation.com/repository/public/")
        }
    }
}

subprojects {
    apply(plugin = "java-library")

    java {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(17))
        }
    }
}

ignitionModule {
    name.set(moduleName)
    id.set(moduleId)
    moduleVersion.set(moduleVersion)
    description.set(moduleDescription)
    projectUrl.set(moduleProjectUrl)
    license.set(moduleLicense)

    hooks.putAll(
        mapOf(
            "G" to "${module_package}.gateway.${class_prefix}GatewayHook"
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

import com.inductiveautomation.ignition.gateway.model.AbstractGatewayModuleHook;

public class ${class_prefix}GatewayHook extends AbstractGatewayModuleHook {
    @Override
    public void setup(com.inductiveautomation.ignition.gateway.model.GatewayContext context) {
        context.getLogger().info("${module_name} setup complete");
    }

    @Override
    public void startup(com.inductiveautomation.ignition.gateway.model.GatewayContext context) {
        context.getLogger().info("${module_name} started");
    }

    @Override
    public void shutdown() {
        // No-op
    }
}
EOF2

echo "Scaffold created at '$module_dir'"
