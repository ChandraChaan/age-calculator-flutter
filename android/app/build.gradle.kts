import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// AdMob application ID. Defaults to Google's official *test* app ID so the
// app builds without an account. For the Play build pass the real one:
//   flutter build appbundle --android-project-arg=ADMOB_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
// (see docs/ADMOB.md).
val testAdmobAppId = "ca-app-pub-3940256099942544~3347511713"
val admobAppId = (project.findProperty("ADMOB_APP_ID") as String?) ?: testAdmobAppId

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.chandra.agecalculator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by the notifications plugin for scheduled reminders.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    defaultConfig {
        applicationId = "com.chandra.agecalculator"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    testImplementation("junit:junit:4.13.2")
}
// Release builds must carry a well-formed AdMob app ID; Google's test ID is
// allowed but warned about, because then no ads are requested.
val validateAdmob by tasks.registering {
    group = "verification"
    description = "Checks the AdMob app ID used by release builds."
    val adId = admobAppId
    val testId = testAdmobAppId
    doLast {
        if (!Regex("^ca-app-pub-[0-9]{16}~[0-9]{10}$").matches(adId)) {
            throw GradleException(
                "ADMOB_APP_ID is malformed (expected ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY).",
            )
        }
        if (adId == testId) {
            logger.warn(
                "WARNING: this release uses Google's TEST AdMob app id (no ADMOB_APP_ID given). " +
                    "Supply the real ids before a release that should show ads.",
            )
        }
    }
}
tasks.matching { it.name == "assembleRelease" || it.name == "bundleRelease" }
    .configureEach { dependsOn(validateAdmob) }
