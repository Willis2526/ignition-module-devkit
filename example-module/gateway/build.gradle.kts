val ignitionVersion: String by rootProject

dependencies {
    implementation(project(":common"))
    compileOnly("com.inductiveautomation.ignitionsdk:gateway-api:$ignitionVersion")
}
