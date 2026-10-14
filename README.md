# AnimPro — editor de animação 2D

Aplicação Flutter com interface escura de estúdio, canvas de desenho, animação por frames, rigging, ferramentas vetoriais e exportação para ficheiros partilháveis no Android.

## Funcionalidades incluídas

- **Projetos:** criar, abrir, renomear, duplicar e apagar. Lista em grelha com pré-visualização dos traços.
- **Tutorial inicial:** ecrã de boas-vindas, apresentado na primeira abertura.
- **Canvas:** desenho por toque; caneta, borracha, linha, retângulo, elipse e régua graduada.
- **Pincéis:** lápis, tinta, marcador, aerógrafo, giz de cera, marca-texto, pastel e pixel. Ajuste de cor, espessura e opacidade.
- **Edição:** desfazer, refazer, limpar, grelha de referência e onion skin do frame anterior a 30%.
- **Camadas:** Linha, Cor e Fundo. Tocar seleciona; manter pressionado alterna a visibilidade.
- **Timeline:** frames horizontais, duplicação do frame selecionado e reprodução em loop com intervalo de 500 ms.
- **Rigging:** seis pontos de controlo e deformação ponderada dos traços próximos. A pose pode ser guardada como novo frame.
- **Biblioteca de assets:** desenhos vetoriais-base de personagens, natureza e objetos para inserir no canvas.
- **Audio Lip Sync:** importar áudio do telefone, reproduzir/pausar, marcar manualmente poses de boca e aplicar as marcações à timeline.
- **Exportação:** PNG do frame atual, sequência de PNG em ZIP, GIF animado e MP4. O MP4 tenta H.264 usando MediaCodec no Android e utiliza MPEG-4 como alternativa quando o dispositivo não disponibiliza esse encoder. Resoluções 540p, 720p e 1080p; taxa de frames configurável.
- **Base de dados local:** projetos guardados com Isar no dispositivo, sem obrigar a conta.

> **Limites atuais:** o mapa automático de Audio Lip Sync distribui poses ao longo do áudio e é apenas uma base de edição; não é reconhecimento fonético por IA. O rigging usa deformação simples baseada na distância, não um sistema avançado de ossos e mesh. A biblioteca contém formas vetoriais geradas localmente, não um catálogo de imagens externas.

## Instalar o APK diretamente no telefone

1. Abre [Releases](https://github.com/nexauren1/Animations-2D-/releases/tag/mobile-latest) no Android.
2. Descarrega `app-release.apk`.
3. Abre o ficheiro transferido e segue a confirmação de instalação do Android. Instala apenas o APK deste repositório que reconheces.

O GitHub Actions compila o APK de release sempre que há alterações na branch `main). O mesmo fluxo guarda um artefacto de build durante 30 dias.

## Executar o projeto num computador

Requisitos: Flutter SDK estável e Android SDK.

```bash
flutter create --platforms=android --project-name animpro .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

O segundo passo instala as dependências; o gerador Isar cria `lib/models/project_model.g.dart`. Para gerar o pacote:

```bash
flutter build apk --release
```

A compilação Android requer API 24 ou superior devido ao codificador FFmpeg integrado.

## Estrutura do código

- `lib/main.dart` — inicialização, Isar e primeira abertura.
- `lib/models/project_model.dart` — projeto, frame, camada e traço.
- `lib/services/project_store.dart` — operações da base de dados.
- `lib/screens/home_screen.dart` — grelha de projetos.
- `lib/screens/onboarding_screen.dart` — tutorial inicial.
- `lib/screens/canvas_screen.dart` — ferramentas de desenho, camadas, timeline e atalhos.
- `lib/screens/timeline_screen.dart` — frames e reprodução.
- `lib/screens/rigging_screen.dart` — pontos de controlo e deformação.
- `lib/screens/audio_lip_sync_screen.dart` — áudio e marcações de boca.
- `lib/screens/assets_library_screen.dart` — biblioteca de assets.
- `lib/screens/export_screen.dart` — render de imagens e codificação de vídeo/GIF.
