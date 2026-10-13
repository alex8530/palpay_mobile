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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
