allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

ext {
    set("compileSdkVersion", 36)
    set("targetSdkVersion", 36)
    set("minSdkVersion", 21)
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
    plugins.withId("com.android.library") {
        val androidExtension = extensions.findByName("android") ?: return@withId
        val namespaceGetter = androidExtension.javaClass.methods.find { it.name == "getNamespace" } ?: return@withId
        val currentNamespace = namespaceGetter.invoke(androidExtension) as? String
        if (!currentNamespace.isNullOrBlank()) {
            return@withId
        }

        val manifestFile = project.file("src/main/AndroidManifest.xml")
        if (!manifestFile.exists()) {
            return@withId
        }

        val manifestPackage = Regex("""package\s*=\s*"([^"]+)"""")
            .find(manifestFile.readText())
            ?.groupValues
            ?.getOrNull(1)
            ?: return@withId

        val namespaceSetter = androidExtension.javaClass.methods.find {
            it.name == "setNamespace" && it.parameterTypes.size == 1
        } ?: return@withId

        namespaceSetter.invoke(androidExtension, manifestPackage)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

