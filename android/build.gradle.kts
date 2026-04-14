import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.dsl.KotlinJvmCompilerOptions

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

    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }

    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension

            // --- ADD THESE LINES HERE ---
            android.compileSdkVersion(36) 
            // This forces plugins like jailbreak_detection to use SDK 36
            // ----------------------------
            
            // [FIX] Inject namespace if missing (required by AGP 8.0+)
            if (android.namespace == null) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestXml = manifestFile.readText()
                    val packageRegex = Regex("""package="([^"]+)"""")
                    val matchResult = packageRegex.find(manifestXml)
                    if (matchResult != null) {
                        android.namespace = matchResult.groupValues[1]
                        println("DEBUG: Injected namespace ${android.namespace} for project ${project.name}")
                    }
                }
                
                // Fallback if no package found in manifest
                if (android.namespace == null) {
                    val projectName = project.name
                    android.namespace = when (projectName) {
                        "flutter_jailbreak_detection" -> "appmire.be.flutterjailbreakdetection"
                        else -> "com.example.${projectName.replace("-", "_")}"
                    }
                }
            }

            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        
        tasks.withType<JavaCompile> {
            options.compilerArgs.add("-Xlint:-options")
        }

        // [FIX] Ensure Kotlin also targets JVM 17 to match Java configuration
        // Using modern compilerOptions DSL required by Kotlin 2.2.20+
        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
