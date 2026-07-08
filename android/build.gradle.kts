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

// AGP 8+ UYUMLULUK YAMASI
// flutter_jailbreak_detection gibi eski paketler namespace tanımlamaz.
// compileSdk 35: freeRASP 8.x, Android 15 (API 35) ekran-kaydı tespiti
// (SCREEN_RECORDING_STATE_VISIBLE / add/removeScreenRecordingCallback) kullanır;
// 34'te bu semboller çözülmez ve :freerasp:compileDebugKotlin kırılır. App zaten
// compileSdk 36'da derleniyor, 35 plugin'ler için güvenli (minSdk 28 değişmez).
subprojects {
    val applyPatch: (Project) -> Unit = { proj ->
        if (proj.plugins.hasPlugin("com.android.library")) {
            val androidExt = proj.extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
            if (androidExt != null) {
                androidExt.compileSdk = 35
                if (androidExt.namespace == null) {
                    androidExt.namespace = proj.group.toString()
                }
                androidExt.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }

    if (project.state.executed) {
        applyPatch(project)
    } else {
        project.afterEvaluate { applyPatch(this) }
    }
    
    // Kotlin görevleri için JVM hedefi ayarla
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }

    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension>("kotlin") {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

