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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url 'https://api.mapbox.com/downloads/v2/releases/maven'
            authentication { basic(BasicAuthentication) }
            credentials {
                username = "mapbox"
                password = project.properties['MAPBOX_DOWNLOADS_TOKEN'] ?: ""
            }
        }
    }
}