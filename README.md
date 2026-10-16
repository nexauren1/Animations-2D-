# AnimPro — editor de animação 2D

**Versão de atualização:** `1.4.1+7` · interface em português e inglês.

Editor de animação 2D para Android, construído com Flutter. O foco é desenhar, organizar frames, experimentar poses e exportar animações sem obrigar o utilizador a criar uma conta.

## Funcionalidades

- **Projetos locais:** criar, abrir, renomear, duplicar e apagar projetos.
- **Backups portáteis:** exportar um projeto como ficheiro `.animpro` e importá-lo noutro dispositivo.
- **Desenho:** caneta, borracha, linha, retângulo, elipse e régua graduada.
- **Pincéis com amostra visual:** lápis, caneta técnica, tinta e marcador gratuitos; aerógrafo, pincel suave, pastel, pincel seco, pixel e efeitos avançados desbloqueados no Pro.
- **Efeitos gratuitos:** brilho neon, luz energética, rasto de movimento e linhas tracejadas; os efeitos também são renderizados na exportação de imagem e de vídeo.
- **Interface bilingue:** português ou inglês, com a preferência guardada no dispositivo.
- **Cores:** paleta com 36 cores de acesso rápido, código HEX personalizado e controlos HSV para matiz, saturação e luminosidade. A cor HEX permite definir qualquer cor RGB de 24 bits.
- **Edição:** editor horizontal, pré-visualização de pincéis com amostras de traço, desfazer/refazer, grelha de referência, camadas, régua graduada e onion skin.
- **Pré-visualização:** reprodução em ecrã completo com loop, controlo de FPS, avanço/retrocesso por frame e faixas de áudio sincronizadas por frame.
- **Biblioteca de áudio online:** pré-escuta antes de transferir, download para o dispositivo, faixas Pro e colocação do som no frame escolhido. O catálogo é atualizado pelo site sem lançar novo APK.
- **Timeline:** criar frames vazios, duplicar/apagar frames e ajustar a reprodução para 6, 12, 24, 30 ou 60 FPS. O FPS fica guardado no projeto e é usado como valor inicial na exportação.
- **Rigging simples:** pontos de controlo para modificar poses e guardá-las como frames.
- **Áudio e lip sync:** as faixas de áudio do projeto ficam guardadas localmente e são reproduzidas na pré-visualização a partir do frame definido. O MP4 exportado continua silencioso: a mistura/muxagem de áudio no vídeo ainda não está implementada.
- **Projetos prontos:** seis exemplos de base e um combate Stickman estilizado de 16 frames com socos, esquivas, bloqueios, pontapé aéreo e impactos cartunescos. Todos os frames são editáveis.
- **Biblioteca de assets e downloads:** formas vetoriais-base, modelos de animação e pacotes de conteúdo descarregáveis para guardar no dispositivo e editar offline.
- **Exportação:** PNG do frame e MP4 até 720p gratuitos; 1080p, GIF, sequência PNG em ZIP e 60 FPS são Pro. Os ficheiros são copiados automaticamente para Downloads/AnimPro no Android 10+; em versões anteriores usa-se o armazenamento específico do AnimPro. O MP4 depende do codificador H.264/MediaCodec do dispositivo e permanece sem áudio.
- **Conta:** registo/entrada com e-mail e palavra-passe, redefinição de palavra-passe, verificação de e-mail e entrada Google, quando o projeto Firebase está configurado.
- **Modo sem conta:** os projetos continuam disponíveis localmente no telefone.

### Limites conhecidos

O mapa aproximado de Audio Lip Sync é uma base de edição manual, não reconhecimento fonético por IA. A versão atual não mistura áudio no MP4 nem oferece uma timeline de várias faixas, gravação de voz ou corte/fades de áudio como um editor de vídeo. O rigging atual é uma deformação simples de uma área e ainda não é um sistema completo de esqueletos independentes para várias personagens/objetos. Os backups Google Drive e Dropbox ainda não estão implementados; por enquanto, usa o ficheiro `.animpro` para transferir projetos. A biblioteca de áudio online fica vazia até serem publicados ficheiros licenciados no catálogo.

## Instalar e escolher uma versão

As versões assinadas são disponibilizadas na [release mobile-latest](https://github.com/nexauren1/Animations-2D-/releases/tag/mobile-latest).

- **`AnimPro-release-signed.apk`** — único APK universal de lançamento, assinado com a chave permanente e otimizado para distribuição. Não é uma versão de teste.
- **`SHA256SUMS.txt`** — hash SHA-256 para confirmar a integridade do APK transferido.

O GitHub Actions gera apenas este APK para distribuição e verifica a assinatura antes de atualizar a release `mobile-latest`. O workflow guarda também um mapa privado de símbolos de depuração no artefacto interno, separado dos ficheiros públicos.

## Site oficial e páginas legais

O site oficial está publicado em [AnimPro](https://nexauren1.github.io/Animations-2D-/), com página inicial, Política de Privacidade, Termos e página de retorno PayPal. O workflow **Deploy AnimPro website** concluiu a publicação com sucesso em 16 de outubro de 2026. Os botões de download apontam diretamente para o APK e para o checksum, sem encaminhar o utilizador para a página principal do repositório.

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

## AnimPro Pro e pagamentos via Cloudflare Worker

O checkout da aplicação usa o Worker `animations2d` em `https://animations2d.nexaurenstore.workers.dev`. O código está em `cloudflare-worker/src/index.js` e a configuração de deploy está em `wrangler.toml`. O checkout só aceita a conta Firebase autenticada; uma licença Pro só é escrita depois de a API PayPal confirmar a captura ou o estado da subscrição através de um webhook assinado.

### Configuração no Cloudflare

Em **Workers & Pages → animations2d → Settings → Variables and Secrets**, mantém os secrets existentes `PAYPAL_CLIENT_ID` e `PAYPAL_CLIENT_SECRET` com credenciais **Sandbox**. Não coloques credenciais Live enquanto o fluxo Sandbox não estiver validado.

Acrescenta estes dois **Secrets** do Worker:

- `FIREBASE_SERVICE_ACCOUNT_JSON` — conteúdo JSON de uma conta de serviço criada para este projeto Firebase. Dá-lhe apenas a permissão de dados necessária para ler/escrever documentos Firestore (`roles/datastore.user`); não reutilizes a chave de deploy com permissões administrativas. A chave privada nunca deve entrar no Git ou no APK.
- `PAYPAL_WEBHOOK_ID` — ID que o PayPal atribui ao webhook registado para este Worker.

Acrescenta estas **Variables** (texto simples):

- `FIREBASE_PROJECT_ID` — ID exato do projeto Firebase utilizado pela aplicação.
- `FIREBASE_API_KEY` — chave de configuração Web/API do mesmo projeto Firebase. Não é a chave privada da conta de serviço.

O `wrangler.toml` define o ambiente PayPal Sandbox, o plano mensal `P-5LD012631E418920JNLIRDEA` e os endereços de retorno. A opção `keep_vars = true` preserva variáveis definidas no painel durante um deploy pelo Git. Os segredos cifrados também são preservados pelos deploys.

### Configurar o webhook PayPal

Na aplicação Sandbox do PayPal, regista como webhook este endereço HTTPS:

`https://animations2d.nexaurenstore.workers.dev/api/paypal/webhook`

Subscreve pelo menos os eventos `CHECKOUT.ORDER.APPROVED`, `BILLING.SUBSCRIPTION.ACTIVATED`, `BILLING.SUBSCRIPTION.UPDATED`, `BILLING.SUBSCRIPTION.CANCELLED`, `BILLING.SUBSCRIPTION.SUSPENDED`, `BILLING.SUBSCRIPTION.EXPIRED`, `BILLING.SUBSCRIPTION.PAYMENT.FAILED`, `PAYMENT.SALE.COMPLETED`, `PAYMENT.SALE.REFUNDED`, `PAYMENT.SALE.REVERSED`, `PAYMENT.CAPTURE.REFUNDED` e `PAYMENT.CAPTURE.REVERSED`. Copia o ID do webhook criado e guarda-o como o secret `PAYPAL_WEBHOOK_ID` no Cloudflare. O Worker verifica a assinatura junto do PayPal antes de processar qualquer evento.

### Firestore e verificação

A conta de serviço tem de pertencer ao mesmo projeto indicado em `FIREBASE_PROJECT_ID`. Antes de testar compras, confirma na Firebase Console que as regras Firestore permitem ao utilizador autenticado ler apenas o seu documento `proEntitlements/{uid}` e não lhe permitem escrever ou apagar licenças. O ficheiro `firestore.rules` deste repositório inclui essa regra e preserva a regra de leaderboard existente no repositório; compara-o com as regras atualmente publicadas e preserva quaisquer regras adicionais necessárias antes de publicar.

Depois de ligar **Settings → Builds → Git repository** ao repositório `nexauren1/Animations-2D-` com a branch `main`, cada push validado na `main` deve disparar o deploy do Worker. Confirma primeiro `https://animations2d.nexaurenstore.workers.dev/health` (esperado: JSON com `ok: true`). Depois testa pagamentos apenas com contas Sandbox e confirma os documentos no Firestore.

O checkout usa exclusivamente o Worker Cloudflare. O workflow antigo de deploy PayPal por Firebase Functions foi retirado para evitar tentativas de deploy incompatíveis com esta arquitetura. A compra permanente custa USD 50 e a subscrição mensal USD 5 no código atual. Só migres para Live depois de testar aprovação, cancelamento, falhas, reembolso e revogação da licença.

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

