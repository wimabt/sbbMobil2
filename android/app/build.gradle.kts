import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // FCM için: google-services.json dosyasını işler (OneSignal push bildirimleri için zorunlu)
    id("com.google.gms.google-services")
}

// Google Maps API key: set MAPS_API_KEY in android/local.properties (gitignored).
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val mapsApiKey =
    localProperties.getProperty("MAPS_API_KEY") ?: "YOUR_FALLBACK_KEY"

// Play upload keystore: android/key.properties (gitignored). Paths in storeFile are relative to android/.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.smartsamsun.mobil"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Core library desugaring: Java 8+ API'leri eski Android sürümlerinde kullanmak için
        // flutter_local_notifications paketi tarafından gerekli
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Release build'de `lintVitalAnalyzeRelease`, Windows'ta lint-cache jar'ını
    // kilitleyip "dosya başka bir işlem tarafından kullanılıyor" (FileSystemException)
    // hatasıyla build'i düşürüyordu. Lint'i release derlemesinden ayırıyoruz;
    // statik analiz `flutter analyze` ile zaten yapılıyor.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    defaultConfig {
        // Play Store'da yayın sonrası DEĞİŞTİRİLEMEZ. Firebase google-services.json
        // ve Maps API key kısıtlaması bu paket adına bağlı (bkz. cila.md #3).
        applicationId = "com.smartsamsun.mobil"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 9.0 (API 28) minimum — ar_flutter_plugin_2 (şartname §6.8.3.4
        // dünya-anchor'lı AR sahnesi için) Android Pie altında çalışmıyor.
        // ARCore device list zaten genel olarak Android 8+ cihazlardan oluşur,
        // bu yüzden bumping pratik olarak kullanıcı kaybı yaratmaz.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Multidex desteği (çok sayıda method referansı için)
        multiDexEnabled = true

        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties yoksa yalnızca configuration-time fallback —
            // aşağıdaki taskGraph guard'ı gerçek bir release paketlemesini
            // keystore'suz FAIL ettirir (sessiz debug imzalı release'i önler).
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKeystore) "release" else "debug",
            )
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// ── Release imza guard'ı (§10.4.1) ─────────────────────────────────────────
// key.properties yokken release paketi üretilmeye çalışılırsa build'i düşür.
// Eskiden sessizce debug anahtarıyla imzalanıyordu — dağıtıma çıkabilecek
// bir paketin debug key taşıması hem güvenlik hem Play yayın engelidir.
// Cihazda release performans testi için bilinçli kaçış yolu:
//   flutter build apk --release ... -PallowDebugSigning=true  (gradle.properties
//   üzerinden değil, tek seferlik -P bayrağıyla kullanın.)
val allowDebugSigning = (project.findProperty("allowDebugSigning") as? String) == "true"
gradle.taskGraph.whenReady {
    val packagingRelease = allTasks.any {
        it.name == "packageRelease" || it.name == "packageReleaseBundle"
    }
    if (packagingRelease && !hasReleaseKeystore && !allowDebugSigning) {
        throw GradleException(
            "android/key.properties bulunamadı — release build DEBUG anahtarıyla imzalanamaz.\n" +
                "Çözüm: android/key.properties oluşturun (keyAlias, keyPassword, storeFile, storePassword).\n" +
                "Bilinçli olarak debug imzalı release istiyorsanız: -PallowDebugSigning=true",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring: Java 8+ API desteği için gerekli
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // ARCore: Scene Viewer ile kamera üzerinden AR görüntüleme
    implementation("com.google.ar:core:1.47.0")
    // Native geofencing (GeofencingClient) — geolocator dolaylı getiriyor ama
    // doğrudan kullandığımız için açıkça bildiriyoruz.
    implementation("com.google.android.gms:play-services-location:21.3.0")
    // NotificationCompat / ContextCompat (receiver bildirimleri için).
    implementation("androidx.core:core-ktx:1.13.1")
}

// Windows builds can fail when Gradle tries to apply Unix-style permissions
// (e.g. 644) while copying Flutter assets. Disable explicit permission setting
// for Flutter's asset copy tasks so Gradle doesn't attempt chmod.
tasks.matching { it.name.startsWith("copyFlutterAssets") }.configureEach {
    (this as? org.gradle.api.tasks.Copy)?.apply {
        fileMode = -1
        dirMode = -1
    }
}
