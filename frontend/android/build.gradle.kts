allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    fun applyNamespaceWorkaround() {
        if (project.hasProperty("android")) {
            val android = project.property("android") as com.android.build.gradle.BaseExtension
            if (android.namespace == null) {
                android.namespace = "com.srishty.fallback." + project.name.replace("-", "_")
            }
            
            // Fix for "Setting the namespace via the package attribute... is no longer supported"
            val manifestFile = project.file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val content = manifestFile.readText()
                if (content.contains("package=")) {
                    val newContent = content.replace(Regex("""package="[^"]*""""), "")
                    manifestFile.writeText(newContent)
                }
            }
        }
    }

    if (project.state.executed) {
        applyNamespaceWorkaround()
    } else {
        project.afterEvaluate {
            applyNamespaceWorkaround()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
