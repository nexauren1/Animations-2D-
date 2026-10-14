# AnimPro — editor de animação 2D

Aplicação Flutter para desenho por toque, gestão de projetos locais, animação por frames e rigging básico. A interface usa um tema escuro com canvas branco.

## O que esta versão contém

- **Projetos:** criar, abrir, renomear, duplicar e apagar projetos.
- **Persistência local:** projetos e frames guardados numa base Isar no dispositivo.
- **Canvas:** desenho com o dedo, caneta preta de 3 px, borracha branca de 10 px, desfazer, refazer e limpar a camada atual.
- **Frames:** timeline horizontal, novo frame por duplicação e playback em loop com 500 ms por frame.
- **Onion skin:** frame anterior desenhado por baixo com 30% de opacidade.
- **Camadas:** Linha, Cor e Fundo, com seleção de camada.
- **Rigging:** seis controlos estimados a partir do bounding box dos traços. Arrastar um controlo aplica deslocamento ponderado aos pontos próximos e permite guardar a pose como novo frame.

## Preparar o ambiente

Requisitos: Flutter SDK instalado e um emulador Android ou dispositivo ligado por USB.

Este repositório foi iniciado sem o esqueleto nativo de uma aplicação Flutter. Na primeira execução, cria os ficheiros de plataforma Android:

```bash
flutter create --platforms=android --project-name animpro .
```

Depois, na raiz do repositório:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

O comando `build_runner` gera `lib/models/project_model.g.dart`, necessário pelo Isar. É preciso executá-lo novamente se os modelos Isar forem alterados.

Para selecionar um dispositivo específico:

```bash
flutter devices
flutter run -d <device_id>
```

## Estrutura principal

- `lib/main.dart` — inicialização de Flutter e Isar.
- `lib/models/project_model.dart` — projeto, frame, layer e stroke.
- `lib/services/project_store.dart` — persistência local.
- `lib/screens/home_screen.dart` — grelha de projetos.
- `lib/screens/canvas_screen.dart` — canvas, ferramentas e camadas.
- `lib/screens/timeline_screen.dart` — frames e reprodução.
- `lib/screens/rigging_screen.dart` — controlos do rig e deformação simples.

## Limitações desta etapa

A deformação do rigging é deliberadamente simples e baseada na distância aos controlos; não substitui um sistema de bones/mesh com pesos profissionais. A exportação de MP4/GIF, sincronização labial por áudio, biblioteca de assets e animação avançada ainda não estão incluídas nesta base.
