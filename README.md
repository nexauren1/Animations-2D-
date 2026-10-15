# AnimPro — editor de animação 2D

Editor de animação 2D para Android, construído com Flutter. O foco é desenhar, organizar frames, experimentar poses e exportar animações sem obrigar o utilizador a criar uma conta.

## Funcionalidades

- **Projetos locais:** criar, abrir, renomear, duplicar e apagar projetos.
- **Backups portáteis:** exportar um projeto como ficheiro `.animpro` e importá-lo noutro dispositivo.
- **Desenho:** caneta, borracha, linha, retângulo, elipse e régua graduada.
- **Pincéis:** lápis, tinta, marcador, aerógrafo, giz de cera, marca-texto, pastel e pixel.
- **Edição:** desfazer/refazer, grelha de referência, camadas e onion skin.
- **Timeline:** criar frames vazios, duplicar/apagar frames e ajustar a reprodução para 6, 12, 24, 30 ou 60 FPS. O FPS fica guardado no projeto e é usado como valor inicial na exportação.
- **Rigging simples:** pontos de controlo para modificar poses e guardá-las como frames.
- **Áudio:** importar um áudio, ouvir e marcar manualmente poses de boca.
- **Biblioteca de assets:** formas vetoriais-base para inserir no canvas.
- **Exportação:** PNG do frame, sequência de PNG em ZIP, GIF e MP4. O MP4 tenta H.264 em dispositivos compatíveis e utiliza um encoder alternativo quando necessário.
- **Conta:** registo/entrada com e-mail e palavra-passe, redefinição de palavra-passe, verificação de e-mail e entrada Google, quando o projeto Firebase está configurado.
- **Modo sem conta:** os projetos continuam disponíveis localmente no telefone.

### Limites conhecidos

O mapa automático de Audio Lip Sync é uma base de edição manual, não reconhecimento fonético por IA. O rigging é baseado em deformação simples e não num sistema completo de ossos e malha. A conta Firebase ainda não sincroniza projetos automaticamente entre dispositivos; usa o backup `.animpro` para transferir projetos.

## Instalar e escolher uma versão

As versões assinadas são disponibilizadas na [release mobile-latest](https://github.com/nexauren1/Animations-2D-/releases/tag/mobile-latest).

- **`AnimPro-normal-release.apk`** — APK universal, maior, com bibliotecas para várias arquiteturas Android.
- **`AnimPro-test-optimized-arm64.apk`** — APK de teste otimizado para dispositivos Android `arm64-v8a`. Não funciona em telefones que só suportam 32 bits. Tem o mesmo package ID e a mesma chave da versão normal; instalá-lo substitui a versão normal, não instala uma segunda cópia lado a lado.
- **`SHA256SUMS.txt`** — hashes para verificar os ficheiros transferidos.

O GitHub Actions compila e verifica as assinaturas automaticamente. Os artefactos de execução ficam disponíveis por 30 dias.

## Configuração Firebase Authentication

O package ID Android é `com.nexauren.animpro`.

No Firebase Console, abre **Authentication → Sign-in method** e ativa **Email/Password** e **Google**. Em **Project settings → Your apps**, regista a aplicação Android com o package ID acima e acrescenta os seguintes fingerprints da chave permanente de lançamento:

- **SHA-1:** `AF:FC:8E:38:94:00:F4:58:B5:71:BA:61:86:1F:7B:81:61:CE:2E:6B`
- **SHA-256:** `CA:D9:5E:B6:FD:EA:D6:13:77:10:59:23:3B:F0:C1:17:32:82:FD:21:27:90:50:C8:18:0E:9A:B0:E6:46:16:EC`

Nas definições do repositório GitHub, em **Settings → Secrets and variables → Actions → Variables**, adiciona estas variáveis de configuração do Firebase:

- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `GOOGLE_WEB_CLIENT_ID` — o OAuth Client ID do tipo **Web application**. Se `google-services.json` já incluir um cliente OAuth com `client_type: 3`, o Android pode lê-lo da configuração nativa; nesse caso, esta variável pode ficar vazia. Caso contrário, preenche-a.

Os identificadores do Firebase são valores de configuração, não a chave privada de assinatura. Obtém-os nas definições do teu projeto Firebase. Depois de criares ou alterares variáveis, executa novamente o workflow **Build Android APK** para incluir a configuração no APK. Para o login Google no Android, confirma que `google-services.json` contém um cliente OAuth do tipo Web (`client_type: 3`); se não contiver, define `GOOGLE_WEB_CLIENT_ID` com o ID de cliente Web do mesmo projeto Firebase. Se não houver configuração Firebase válida, o editor local continua a funcionar e o ecrã de conta informa que a autenticação ainda não está configurada.

## GitHub Actions Secrets de assinatura

A chave permanente não deve ser guardada no repositório. Em **Settings → Secrets and variables → Actions → Secrets**, mantém estes quatro secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

O script `.github/scripts/prepare_android_signing.py` valida a chave e prepara a assinatura no runner. Guarda uma cópia privada do ficheiro `.jks` e das palavras-passe fora do GitHub. Todas as versões futuras devem usar a mesma chave para permitir atualizações normais.

## Desenvolvimento

Requisitos: Flutter SDK estável e Android SDK.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Para um APK universal local:

```bash
flutter build apk --release
```

A compilação Android exige API 24 ou superior devido ao encoder de vídeo integrado.

## Firebase Authentication (Android)

O projeto já inclui ecrã de conta com criação de conta e início de sessão por e-mail/palavra-passe, redefinição da palavra-passe, verificação do e-mail e início de sessão com Google.

Este repositório gera a pasta `android/` durante o GitHub Actions, em vez de a manter no código-fonte. Para adicionar o ficheiro de configuração Android do Firebase, coloca `google-services.json` na **raiz do repositório**, ao lado de `pubspec.yaml`. O script `.github/scripts/configure_firebase_android.py` valida o package `com.nexauren.animpro`, copia o ficheiro para `android/app/google-services.json` durante a compilação e ativa o plugin Google Services.

No Firebase Console:
1. Regista uma aplicação Android com o package exato `com.nexauren.animpro`.
2. Adiciona o SHA-1 e o SHA-256 do certificado de release em Project settings → Your apps.
3. Em Authentication → Sign-in method, ativa **Email/Password** e **Google**.
4. Descarrega um novo `google-services.json` depois de ativares Google Sign-In e coloca-o na raiz do repositório.
5. Confirma que as GitHub Actions Variables `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID` e `FIREBASE_PROJECT_ID` estão preenchidas se estiveres a usar a configuração por variáveis. Para o login Google, usa o cliente OAuth Web incluído no `google-services.json` ou define `GOOGLE_WEB_CLIENT_ID` com um ID do tipo Web do mesmo projeto Firebase.

O `google-services.json` é configuração de cliente Firebase, não uma chave de conta de serviço. Nunca coloques chaves privadas de servidor ou ficheiros de service account no repositório. Restringe a chave de API conforme os serviços que a aplicação usa.

