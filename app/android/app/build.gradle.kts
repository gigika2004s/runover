import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

// Só assina com a upload key quando o arquivo está completo; um
// key.properties parcial cai para debug em vez de quebrar o Gradle Sync.
val storePath = keystoreProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }
val keyAliasValue = keystoreProperties.getProperty("keyAlias")?.takeIf { it.isNotBlank() }
val keyPasswordValue = keystoreProperties.getProperty("keyPassword")?.takeIf { it.isNotBlank() }
val storePasswordValue = keystoreProperties.getProperty("storePassword")?.takeIf { it.isNotBlank() }
val releaseStoreFile = storePath?.let { file(it) }
val hasReleaseKey = releaseStoreFile?.isFile == true && keyAliasValue != null &&
    keyPasswordValue != null && storePasswordValue != null

android {
    namespace = "com.runover.runover_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.runover.runover_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Usa a chave de upload quando app/android/key.properties existe
            // (arquivo local, fora do Git); sem ela, cai para a chave de debug
            // para não quebrar `flutter run --release` nem a CI.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.maybeCreate("release").apply {
                    keyAlias = keyAliasValue!!
                    keyPassword = keyPasswordValue!!
                    storeFile = releaseStoreFile!!
                    storePassword = storePasswordValue!!
                }
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
