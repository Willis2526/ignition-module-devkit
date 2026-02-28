plugins {
    id("io.ia.sdk.modl") version "0.5.0"
}

group = "com.example.hellomodule"

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
            "G" to "com.example.hellomodule.gateway.HelloGatewayHook"
        )
    )

    projectScopes.putAll(
        mapOf(
            ":gateway" to "G",
            ":common" to "GC"
        )
    )
}
