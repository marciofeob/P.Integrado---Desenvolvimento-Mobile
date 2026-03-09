allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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

// NOVA VERSÃO DA CORREÇÃO:
subprojects {
    plugins.withType<com.android.build.gradle.api.AndroidBasePlugin> {
        val android = extensions.getByType<com.android.build.gradle.BaseExtension>()
        if (android.namespace == null) {
            android.namespace = project.group.toString()
        }
    }
}