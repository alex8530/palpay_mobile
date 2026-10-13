allprojects {
    repositories {
        // Flutter engine jars pre-downloaded with curl; Gradle's own downloads
        // from storage.googleapis.com stall on this network.
        val engineMirror = file(System.getProperty("user.home") + "/.flutter_engine_mirror")
        if (engineMirror.isDirectory) {
            maven { url = engineMirror.toURI() }
        }
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

// Plugins (e.g. image_picker) pin older AGP/Kotlin on their buildscript
// classpath. The app's AGP 9.1.0 / Kotlin 2.4.0 are what actually load, so
// align them instead of downloading unused versions (those downloads stall here).
subprojects {
    buildscript.configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                useVersion("9.1.0")
            }
            if (requested.group == "org.jetbrains.kotlin" && requested.name == "kotlin-gradle-plugin") {
                useVersion("2.4.0")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
