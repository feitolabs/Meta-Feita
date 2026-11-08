# Guia de Publicação Android (Google Play Store) — Meta Feita

Este documento descreve as etapas para assinar e gerar o pacote de distribuição oficial (`.aab` — Android App Bundle) para a Google Play Store.

---

## 1. Gerar a Chave de Assinatura (Keystore)

No terminal (PowerShell ou Bash), execute o comando do `keytool` (incluído no JDK):

```bash
keytool -genkey -v -keystore meta-feita-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias metafeita
```

> [!CAUTION]
> Guarde o arquivo `meta-feita-release.jks` e as senhas em local seguro. **Nunca** faça commit deste arquivo ou das senhas no repositório Git.

---

## 2. Configurar o arquivo `key.properties`

Crie o arquivo `app/android/key.properties` (que já está incluso no `.gitignore`):

```properties
storePassword=SUA_SENHA_DO_KEYSTORE
keyPassword=SUA_SENHA_DO_ALIAS
keyAlias=metafeita
storeFile=../meta-feita-release.jks
```

---

## 3. Configurar Assinatura no Gradle (`app/android/app/build.gradle.kts`)

O Gradle do projeto pode ser configurado com o bloco de assinatura para release:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}
```

---

## 4. Gerar o Android App Bundle (`.aab`)

Execute na pasta `app/`:

```bash
cd app
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=API_BASE_URL=https://api-monetizacao.feitolabs.com
```

O arquivo gerado estará em:
```
app/build/app/outputs/bundle/release/app-release.aab
```

---

## 5. Publicação no Google Play Console

1. Acesse o [Google Play Console](https://play.google.com/console).
2. Crie ou selecione o app **Meta Feita**.
3. Crie uma nova versão no canal de Teste Fechado ou Produção.
4. Faça o upload do arquivo `app-release.aab`.
5. Preencha as seções obrigatórias:
   - **Ícone e gráficos**: Utilize os arquivos de alta resolução em `CONTEXTOS/2-android/google-play/ic_play_store_512.png`.
   - **Política de Privacidade**: Aponte para a URL dos Termos e Privacidade (também disponíveis na tela de Configurações do app).
   - **Segurança de Dados**: Declare que o app **não coleta nem compartilha dados financeiros pessoais**, operando com armazenamento estritamente local (`localstorage`).
