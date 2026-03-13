plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// 🔥 MELHORIA 1: Função para ler o .env da raiz do projeto
fun getEnvProperty(key: String): String? {
    val envFile = rootProject.file("../.env") // Sobe um nível para a raiz do projeto
    
    if (!envFile.exists()) {
        println("⚠️ Arquivo .env não encontrado em: ${envFile.absolutePath}")
        return null
    }
    
    return envFile.readLines()
        .firstOrNull { line -> line.startsWith("$key=") }
        ?.substringAfter("$key=")
        ?.trim()
        ?.replace("\"", "") // Remove aspas se houver
}

android {
    namespace = "com.example.transporte_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.transporte_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 🔥 MELHORIA 2: Prioridade: 1º .env, 2º variável ambiente, 3º vazio
        val mapsApiKey = 
            getEnvProperty("GOOGLE_MAPS_API_KEY") ?: 
            System.getenv("MAPS_API_KEY") ?: 
            System.getenv("GOOGLE_MAPS_API_KEY") ?: ""
        
        // 🔥 MELHORIA 3: Log para debug (opcional)
        if (mapsApiKey.isNotEmpty()) {
            println("✅ MAPS_API_KEY carregada com sucesso")
        } else {
            println("⚠️ MAPS_API_KEY não encontrada. O mapa pode não funcionar!")
        }
        
        manifestPlaceholders.putAll(mapOf(
            "MAPS_API_KEY" to mapsApiKey
        ))
    }

    buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
        isMinifyEnabled = false
        isShrinkResources = false
    }
}
}

flutter {
    source = "../.."
}