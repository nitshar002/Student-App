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

// Safely patch the plugins right after they are evaluated by Gradle
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("com.android.application")) {
            val androidProperties = project.extensions.findByName("android")
            androidProperties?.let { ext ->
                try {
                    // Modern property setting for newer Gradle architectures
                    val setCompileSdk = ext.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                    setCompileSdk.invoke(ext, 36)
                } catch (e: Exception) {
                    try {
                        // Fallback method mapping for older plugin configurations
                        val compileSdkVersion = ext.javaClass.getMethod("compileSdkVersion", java.lang.Integer.TYPE)
                        compileSdkVersion.invoke(ext, 36)
                    } catch (ex: Exception) {
                        // Suppress if the module doesn't expose compiling hooks
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}