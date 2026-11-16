plugins {
    id("com.android.application")
}

android {
    namespace = "net.bradeandcake.smokea11y"
    compileSdk = 35

    defaultConfig {
        applicationId = "net.bradeandcake.smokea11y"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
