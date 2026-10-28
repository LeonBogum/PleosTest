plugins { id("com.android.application") }

android {
    namespace = "com.ssafy.pleos"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.ssafy.pleos"
        minSdk = 28
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("ai.pleos.playground:Vehicle:2.3.2")
}
