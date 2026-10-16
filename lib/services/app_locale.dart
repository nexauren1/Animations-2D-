import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material;
import 'package:shared_preferences/shared_preferences.dart';

/// App language preference and the small PT/EN glossary used by UI text widgets.
class AppLocale {
  AppLocale._();

  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('pt'));

  static Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      locale.value = Locale(preferences.getString('animpro_language') == 'en' ? 'en' : 'pt');
    } catch (_) {
      locale.value = const Locale('pt');
    }
  }

  static Future<void> setLanguage(String languageCode) async {
    final code = languageCode == 'en' ? 'en' : 'pt';
    locale.value = Locale(code);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('animpro_language', code);
    } catch (_) {
      // The language changes immediately even if the preference cannot be saved.
    }
  }

  static String t(BuildContext context, String portuguese, String english) =>
      locale.value.languageCode == 'en' ? english : portuguese;

  static String translate(BuildContext context, String source) {
    if (locale.value.languageCode != 'en') return source;

    final frameCount = RegExp(r'^(\d+) frames$').firstMatch(source);
    if (frameCount != null) return '${frameCount.group(1)} frames';

    final packageCount = RegExp(r'^(\d+) pacote(s)$').firstMatch(source);
    if (packageCount != null) return '${packageCount.group(1)} pack(s)';

    final frameRate = RegExp(r'^(\d+) FPS$').firstMatch(source);
    if (frameRate != null) return '${frameRate.group(1)} FPS';

    final renderedFrame = RegExp(r'^A renderizar frame (\d+)/(\d+)…$').firstMatch(source);
    if (renderedFrame != null) {
      return 'Rendering frame ${renderedFrame.group(1)} of ${renderedFrame.group(2)}…';
    }
    final preparingFrame = RegExp(r'^A preparar frame (\d+)/(\d+)…$').firstMatch(source);
    if (preparingFrame != null) {
      return 'Preparing frame ${preparingFrame.group(1)} of ${preparingFrame.group(2)}…';
    }
    final markerCount = RegExp(r'^(\d+) marcas$').firstMatch(source);
    if (markerCount != null) return '${markerCount.group(1)} markers';
    final projectAudio = RegExp(r'^Áudio: (.+)$').firstMatch(source);
    if (projectAudio != null) return 'Audio: ${projectAudio.group(1)}';
    final appliedEffect = RegExp(r'^Efeito aplicado aos próximos traços: (.+)$').firstMatch(source);
    if (appliedEffect != null) {
      return 'Effect applied to upcoming strokes: ${appliedEffect.group(1)}';
    }

    final projectFrameLabel = RegExp(r'^Frame (\d+) / (\d+)$').firstMatch(source);
    if (projectFrameLabel != null) {
      return 'Frame ${projectFrameLabel.group(1)} / ${projectFrameLabel.group(2)}';
    }
    final projectCount = RegExp(r'^(\d+) projeto\(s\)$').firstMatch(source);
    if (projectCount != null) {
      return '${projectCount.group(1)} project(s)';
    }
    final removedProject = RegExp(r'^“(.+)” será removido deste dispositivo\.$').firstMatch(source);
    if (removedProject != null) {
      return '“${removedProject.group(1)}” will be removed from this device.';
    }
    final importedProject = RegExp(r'^Projeto "(.+)" importado com sucesso\.$').firstMatch(source);
    if (importedProject != null) {
      return 'Project "${importedProject.group(1)}" imported successfully.';
    }

    final reducedVideoResolution = RegExp(
      r'^O dispositivo precisou de uma resolução reduzida para exportar o MP4 \((\d+)p\)\.$',
    ).firstMatch(source);
    if (reducedVideoResolution != null) {
      return 'The device needed a lower resolution to export MP4 (${reducedVideoResolution.group(1)}p).';
    }

    final templateFrameCount = RegExp(r'^(\d+) frames · (\d+) FPS$').firstMatch(source);
    if (templateFrameCount != null) {
      return '${templateFrameCount.group(1)} frames · ${templateFrameCount.group(2)} FPS';
    }

    final savedPack = RegExp(r'^Pacote "(.+)" guardado no dispositivo.$').firstMatch(source);
    if (savedPack != null) return 'Pack "${savedPack.group(1)}" saved on this device.';

    final removedPack = RegExp(r'^"(.+)" será removido do armazenamento deste dispositivo.$').firstMatch(source);
    if (removedPack != null) {
      return '"${removedPack.group(1)}" will be removed from this device storage.';
    }

    final savedExport = RegExp(
      r'^Exportação concluída\. Ficheiro guardado em (.+) \(ou na pasta da aplicação em Android antigo\)\.$',
    ).firstMatch(source);
    if (savedExport != null) {
      return 'Export complete. File saved to ${savedExport.group(1)} (or in app-specific storage on older Android).';
    }

    return _english[source] ?? source;
  }


  static const Map<String, String> _english = <String, String>{
    'Não foi possível abrir o AnimPro': 'AnimPro could not be opened',
    'Os teus projetos não foram apagados por esta mensagem. Verifica o espaço disponível no telefone e tenta novamente. Se o problema continuar, evita desinstalar a aplicação antes de fazeres uma cópia de segurança.': 'This message did not delete your projects. Check the free space on your phone and try again. If the problem continues, do not uninstall the app before making a backup.',
    'Tentar novamente': 'Try again',
    'Novo projeto': 'New project',
    'Nome do projeto': 'Project name',
    'Nome': 'Name',
    'Cancelar': 'Cancel',
    'Criar': 'Create',
    'Guardar': 'Save',
    'Renomear projeto': 'Rename project',
    'Apagar projeto?': 'Delete project?',
    'Apagar': 'Delete',
    'Não foi possível criar o projeto. Tenta novamente.': 'Could not create the project. Try again.',
    'Não foi possível criar um projeto com este modelo. Tenta novamente.': 'Could not create a project from this template. Try again.',
    'Não foi possível concluir esta ação. Tenta novamente.': 'Could not complete this action. Try again.',
    'Não foi possível criar o backup deste projeto. Tenta novamente.': 'Could not create a backup of this project. Try again.',
    'Não foi possível importar o backup. Confirma que escolheste um ficheiro AnimPro válido.': 'Could not import the backup. Make sure you selected a valid AnimPro file.',
    'Vamos animar?': 'Ready to animate?',
    'Transforma os teus desenhos em movimento.': 'Turn your drawings into motion.',
    'Novo Projeto': 'New Project',
    'Importar backup de projeto (.animpro)': 'Import project backup (.animpro)',
    'Começa por um exemplo': 'Start with an example',
    'Ver todos': 'View all',
    'Projetos recentes': 'Recent projects',
    'O teu primeiro projeto começa aqui': 'Your first project starts here',
    'Cria um projeto e desenha o primeiro frame.': 'Create a project and draw the first frame.',
    'AnimPro Pro — planos e funções avançadas': 'AnimPro Pro — plans and advanced features',
    'Centro de recursos e downloads': 'Resource centre and downloads',
    'Conta AnimPro': 'AnimPro account',
    'Mais informações': 'More information',
    'Site, privacidade e suporte': 'Website, privacy and support',
    'Sobre o AnimPro': 'About AnimPro',
    'Desenha, cria frames e experimenta poses 2D.': 'Draw, create frames and experiment with 2D poses.',
    'Idioma / Language': 'Language / Idioma',
    'Escolhe o idioma da aplicação.': 'Choose the app language.',
    'Português': 'Português',
    'Inglês': 'English',
    'Mudar idioma': 'Change language',
    'Cor e pincel': 'Colour & brush',
    'Escolhe a cor, espessura e opacidade do próximo traço.': 'Choose the colour, width and opacity of your next stroke.',
    'Estilo do pincel': 'Brush style',
    'Paleta de cores': 'Colour palette',
    'Cor personalizada': 'Custom colour',
    'Introduz um código HEX ou ajusta matiz, saturação e luminosidade.': 'Enter a HEX code or adjust hue, saturation and brightness.',
    'Código HEX': 'HEX code',
    'Matiz': 'Hue',
    'Saturação': 'Saturation',
    'Luminosidade': 'Brightness',
    'Espessura': 'Width',
    'Opacidade': 'Opacity',
    'Pré-visualização': 'Preview',
    'As definições aplicam-se aos novos traços.': 'These settings apply to new strokes.',
    'Aplicar pincel': 'Apply brush',
    'Sobreposição de frames': 'Onion skin',
    'Mostra os frames anterior e seguinte para facilitar o movimento.': 'Show the previous and next frames to guide the movement.',
    'Opacidade dos frames-guia': 'Guide-frame opacity',
    'Voltar aos projetos': 'Back to projects',
    'Exportar': 'Export',
    'Guardar projeto': 'Save project',
    'Grelha': 'Grid',
    'Onion': 'Onion skin',
    'Pincéis': 'Brushes',
    'Timeline': 'Timeline',
    'Rigging': 'Rigging',
    'Áudio': 'Audio',
    'Assets': 'Assets',
    'Efeitos': 'Effects',
    'Exportação': 'Export',
    'Projetos prontos': 'Ready-made projects',
    'Começa com movimento, não com uma página vazia.': 'Start with movement, not a blank page.',
    'Cada exemplo inclui frames editáveis. Abre-o, estuda as poses e transforma-o na tua própria animação.': 'Every example has editable frames. Open it, study the poses, and turn it into your own animation.',
    'Dica: usa a linha temporal e a sobreposição de frames para comparar as poses.': 'Tip: use the timeline and onion skin to compare poses.',
    'Abrir e editar': 'Open and edit',
    'Bola a saltar': 'Bouncing ball',
    'Aprende timing, squash & stretch e arcos de movimento.': 'Learn timing, squash and stretch, and motion arcs.',
    'Flor a florescer': 'Blooming flower',
    'Pratica poses-chave, repetição e crescimento gradual.': 'Practise key poses, repetition, and gradual growth.',
    'Foguetão a descolar': 'Rocket launch',
    'Uma pequena sequência com antecipação, movimento e chama.': 'A short sequence with anticipation, motion, and a flame.',
    'Pêndulo em movimento': 'Swinging pendulum',
    'Estuda arcos, aceleração e desaceleração com uma composição limpa.': 'Study arcs, acceleration, and deceleration in a clean composition.',
    'Personagem a piscar': 'Blinking character',
    'Uma personagem expressiva com olhos e boca que mudam entre poses.': 'An expressive character with eyes and mouth that change between poses.',
    'Cometa veloz': 'Fast comet',
    'Pratica trajetórias, rastos e ritmo numa animação curta.': 'Practise trajectories, trails, and timing in a short animation.',
    'Stickman: Combate Cinematográfico': 'Stickman: Cinematic Fight',
    'Uma sequência de luta estilizada, frame a frame, com socos, esquivas, bloqueios, um pontapé aéreo e um final amigável. Todos os frames são editáveis.': 'A stylised frame-by-frame sparring sequence with punches, dodges, blocks, a jumping kick, and a friendly finish. Every frame is editable.',
    'FUNDAMENTOS': 'FUNDAMENTALS',
    'MOVIMENTO': 'MOTION',
    'FÍSICA': 'PHYSICS',
    'PERSONAGEM': 'CHARACTER',
    'EFEITOS': 'EFFECTS',
    'ANIMAÇÃO DE AÇÃO': 'ACTION ANIMATION',
    'Lápis': 'Pencil',
    'Caneta técnica': 'Technical pen',
    'Tinta': 'Ink',
    'Tinta chinesa': 'Ink brush',
    'Marcador': 'Marker',
    'Aerógrafo': 'Airbrush',
    'Pincel suave': 'Soft brush',
    'Giz de cera': 'Crayon',
    'Marca-texto': 'Highlighter',
    'Pastel': 'Pastel',
    'Pincel seco': 'Dry brush',
    'Pixel': 'Pixel',
    'Brilho neon': 'Neon glow',
    'Rastro de movimento': 'Motion trail',
    'Linha tracejada': 'Dashed line',
    'Luz energética': 'Energy glow',
    'Efeitos de traço': 'Stroke effects',
    'Escolhe um efeito para os próximos traços. As opções ficam disponíveis gratuitamente.': 'Choose an effect for your next strokes. These effects are free to use.',
    'Brilho suave e colorido para contornos luminosos.': 'A soft coloured glow for bright outlines.',
    'Cria um rasto subtil atrás dos traços.': 'Adds a subtle trail behind strokes.',
    'Desenha uma linha interrompida.': 'Draws a broken line.',
    'Um brilho mais intenso para impactos e energia.': 'A stronger glow for impact flashes and energy.',
    'Nenhum áudio selecionado': 'No audio selected',
    'Importar áudio': 'Import audio',
    'Reproduzir': 'Play',
    'Pausar': 'Pause',
    'Parar': 'Stop',
    'Remover áudio': 'Remove audio',
    'Marcar pose': 'Mark pose',
    'Marcar pose atual': 'Mark current pose',
    'Aplicar à timeline': 'Apply to timeline',
    'Frame rate': 'Frame rate',
    'Frame rate (FPS)': 'Frame rate (FPS)',
    'Exportar agora': 'Export now',
    'A exportar…': 'Exporting…',
    'Formato': 'Format',
    'Resolução': 'Resolution',
    'Formato do vídeo': 'Video format',
    'Partilhar para': 'Share to',
    'Depois da exportação, o Android mostra as aplicações compatíveis instaladas no telefone.': 'After export, Android shows compatible apps installed on your phone.',
    'Será codificado a partir de todos os frames do projeto e partilhado para guardar no telefone.': 'The video is encoded from every project frame and shared so you can save it on your phone.',
    'Exporta o frame atual como imagem PNG e abre as opções de partilha do telefone.': 'Export the current frame as a PNG image and open your phone sharing options.',
    'Exporta todos os frames para ficheiros PNG dentro de um ZIP.': 'Export all frames as PNG files inside a ZIP.',
    'Escolhe a proporção adequada à plataforma de destino.': 'Choose the aspect ratio for your target platform.',
    '16:9 Horizontal': '16:9 Landscape',
    '9:16 Vertical': '9:16 Portrait',
    '1:1 Quadrado': '1:1 Square',
    'FPS fica guardado para futuras exportações de vídeo. O PNG não tem taxa de frames.': 'FPS is saved for future video exports. PNG images do not have a frame rate.',
    'Projeto guardado neste dispositivo.': 'Project saved on this device.',
    'Mapa labial aplicado à timeline.': 'Lip-sync map applied to the timeline.',
    'Rigging e poses': 'Rigging and poses',
    'Guardar pose como novo frame': 'Save pose as a new frame',
    'Duplicar': 'Duplicate',
    'Novo frame em branco': 'New blank frame',
    'Apagar frame selecionado': 'Delete selected frame',
    'O projeto precisa de pelo menos um frame.': 'The project needs at least one frame.',
    'Licença não verificada': 'Licence not verified',
    'A verificar licença…': 'Checking licence…',
    'Subscrição ativa': 'Active subscription',
    'Assinar mensalmente': 'Subscribe monthly',
    'Entrar ou criar conta': 'Sign in or create account',
    'Pro Mensal': 'Monthly Pro',
    'Pro Permanente': 'Lifetime Pro',
    'Pro ativo': 'Pro active',
    'Pro permanente': 'Lifetime Pro',
    'A sessão expirou. Entra novamente na tua conta.': 'Your session expired. Sign in again.',
    'Introduz o teu endereço de e-mail.': 'Enter your email address.',
    'Palavra-passe': 'Password',
    'E-mail': 'Email',
    'Iniciar sessão': 'Sign in',
    'Criar conta': 'Create account',
    'Terminar sessão': 'Sign out',
    'Recuperar palavra-passe': 'Reset password',
    'Política de Privacidade': 'Privacy Policy',
    'Termos de Utilização': 'Terms of Use',
    'Centro de recursos': 'Resource centre',
    'PACOTES DISPONÍVEIS': 'AVAILABLE PACKS',
    'Baixar pacote': 'Download pack',
    'A descarregar…': 'Downloading…',
    'Instalado': 'Installed',
    'Remover': 'Remove',
    'Sem resultados': 'No results',
    'Novo pacote': 'New pack',
    'Aplicação': 'App',
    'Português e Inglês': 'Portuguese and English',
    'O desenho, os efeitos visuais, o áudio e a exportação MP4 continuam gratuitos. O Pro desbloqueia apenas ferramentas avançadas.': 'Drawing, visual effects, audio, and MP4 export stay free. Pro unlocks advanced tools only.',
    'As contas online ainda não estão disponíveis': 'Online accounts are not available yet',
    'Podes continuar a desenhar, animar e guardar os teus projetos neste dispositivo. A entrada com conta estará disponível quando o serviço for ativado.': 'You can keep drawing, animating, and saving projects on this device. Account sign-in will be available when the service is activated.',
    'Os projetos locais continuam guardados no teu telefone. Não precisas de criar uma conta para usar o editor.': 'Your local projects remain stored on your phone. You do not need an account to use the editor.',
    'Continuar com Google': 'Continue with Google',
    'A entrada com Google está temporariamente indisponível. Podes usar o e-mail.': 'Google sign-in is temporarily unavailable. You can use email instead.',
    'ou com e-mail': 'or with email',
    'Esqueci-me da palavra-passe': 'Forgot password',
    'A conta não substitui uma cópia de segurança. Nesta versão, os projetos ficam guardados neste dispositivo.': 'An account does not replace a backup. In this version, projects remain stored on this device.',
    'O endereço foi confirmado.': 'Your email address has been verified.',
    'Confirma o endereço para proteger a conta.': 'Verify your email address to protect your account.',
    'Projetos neste dispositivo': 'Projects on this device',
    'A conta não move automaticamente os ficheiros para a nuvem.': 'The account does not automatically upload project files to the cloud.',
    'Biblioteca de assets': 'Asset library',
    'Assets vetoriais': 'Vector assets',
    'Escolhe um elemento para adicionar um desenho-base à camada selecionada. Depois podes editar os traços no canvas.': 'Choose an element to add a starter drawing to the selected layer. You can then edit its strokes on the canvas.',
    'OK': 'OK',
    'Nenhum asset encontrado': 'No assets found',
    'Adiciona': 'Add',
    'Saltar': 'Skip',
    'Dá vida aos teus desenhos': 'Bring your drawings to life',
    'Cria animações 2D em três passos simples.': 'Create 2D animations in three simple steps.',
    'Começar  →': 'Get started  →',
    'Sem conta · Os projetos ficam no teu dispositivo': 'No account needed · Projects stay on your device',
    'Não foi possível importar este áudio. Confirma o formato do ficheiro e tenta novamente.': 'Could not import this audio. Check the file format and try again.',
    'Importa primeiro um ficheiro de áudio.': 'Import an audio file first.',
    'Importa um áudio para marcar o tempo dos fonemas.': 'Import audio to mark phoneme timing.',
    'Importa um áudio com duração válida primeiro.': 'Import an audio file with a valid duration first.',
    'Adiciona fonemas ou cria um mapa aproximado antes de aplicar.': 'Add phonemes or generate an approximate map before applying.',
    'Personagem atual': 'Current character',
    'Preparado para poses de boca': 'Ready for mouth poses',
    'Mapeamento labial': 'Lip sync',
    'Seleciona a forma da boca e marca o instante da fala. O mapa automático gera poses distribuídas; não é reconhecimento fonético por IA.': 'Select a mouth shape and mark the time of speech. The automatic map creates spaced poses; it is not AI phoneme recognition.',
    'Marcar tempo atual': 'Mark current time',
    'Gerar mapa aproximado': 'Generate approximate map',
    'Mapa aproximado criado. Revisa as marcas e ajusta os fonemas manualmente.': 'Approximate map created. Review the marks and adjust phonemes manually.',
    'Marcas na timeline': 'Timeline markers',
    'Ainda não há fonemas marcados.': 'No phonemes have been marked yet.',
    'Adicionar': 'Add',
    'Introduz o endereço de e-mail.': 'Enter your email address.',
    'Palavra-passe demasiado curta.': 'Password is too short.',
    'E-mail enviado': 'Email sent',
    'Não foi possível iniciar sessão.': 'Could not sign in.',
    'Conta criada. Enviámos um e-mail para verificar o endereço.': 'Account created. We sent an email to verify your address.',
    'Sessão iniciada com Google.': 'Signed in with Google.',
    'Verificação enviada': 'Verification sent',
    'Verificar e-mail': 'Verify email',
    'Enviar novamente': 'Resend',
    'A conta online não está disponível neste momento. Podes continuar a usar o editor sem iniciar sessão.': 'Online accounts are not available right now. You can keep using the editor without signing in.',
    'A exportação de vídeo está disponível sem Pro. A exportação a 60 FPS continua a ser uma função avançada.': 'Video export is available without Pro. 60 FPS export remains an advanced feature.',
    'Áudio e marcação de boca': 'Audio and mouth markers',
    'Exportação de vídeo MP4': 'MP4 video export',
    'Exportação até 60 FPS': 'Export up to 60 FPS',
    'Importar e editar o teu áudio é grátis.': 'Importing and editing your audio is free.',
    'Os efeitos visuais são gratuitos. O Pro fica reservado para ferramentas avançadas.': 'Visual effects are free. Pro is reserved for advanced tools.',
    'Cria sem limites criativos': 'Create without creative limits',
    'O que está incluído': 'What is included',
    'O plano mensal renova-se automaticamente até ser cancelado no PayPal. O plano permanente é uma compra única, não uma subscrição anual. Confirma o preço final e as condições no checkout antes de pagar.': 'The monthly plan renews automatically until cancelled through PayPal. The lifetime plan is a one-time purchase, not an annual subscription. Confirm the final price and conditions at checkout before paying.',
    'Site oficial': 'Official website',
    'Privacidade': 'Privacy',
    'Termos': 'Terms',
    'Não foi possível atualizar o estado Pro. Verifica a ligação ao Firestore.': 'Could not refresh Pro status. Check your Firestore connection.',
    'Arrasta os seis pontos. Os traços próximos acompanham o movimento.': 'Drag the six control points. Nearby strokes follow the movement.',
    'Remover pacote?': 'Remove pack?',
    'Conteúdo instalado': 'Installed content',
    'Instala só o conteúdo que precisas.': 'Install only the content you need.',
    'Os pacotes contêm projetos vetoriais pequenos. São descarregados quando pedes, guardados no telefone e podem ser removidos depois.': 'Packs contain small vector projects. They download on request, are stored on your phone, and can be removed later.',
    'Ainda não instalaste pacotes extra. Escolhe um dos pacotes acima quando tiveres internet disponível.': 'You have not installed extra packs yet. Choose a pack above when you have an internet connection.',
    'Usa Wi-Fi quando possível. Os pacotes disponíveis indicam o tamanho aproximado antes do download.': 'Use Wi-Fi when possible. Available packs show their approximate download size.',
    'Usar': 'Use',
    'A exportação de vídeo depende de um codificador H.264 compatível; a mistura de áudio no MP4 ainda está por implementar.': 'Video export requires a compatible H.264 encoder; mixing audio into MP4 is not implemented yet.',
    'Exporta PNG, ZIP, GIF e vídeo MP4 sem subscrição. O vídeo exige um codificador H.264 compatível no dispositivo; a mistura de áudio no MP4 ainda está por implementar.': 'Export PNG, ZIP, GIF, and MP4 video without a subscription. Video requires an H.264 encoder supported by the device; audio mixing into MP4 is not implemented yet.',
    'Importar ficheiro de áudio': 'Import audio file',
    'Nenhuma pose marcada.': 'No poses marked.',
    'Marca as poses enquanto o áudio toca para alinhar o movimento da boca.': 'Mark poses while audio plays to align mouth movement.',
    'Este mapa é um ponto de partida manual, não reconhecimento fonético automático.': 'This map is a manual starting point, not automatic phoneme recognition.',
    'Editar': 'Edit',
    'Sucesso': 'Success',
    'Falhou': 'Failed',
    'Tamanho': 'Size',
    'Abrir': 'Open',
    'Aplicar': 'Apply',
    'Frame atual': 'Current frame',
    'Novo frame': 'New frame',
    'Apagar frame': 'Delete frame',
    'Duplicar frame': 'Duplicate frame',
    'Grelha de referência': 'Reference grid',
    'Camadas': 'Layers',
    'Linha': 'Line',
    'Cor': 'Colour',
    'Fundo': 'Background',
    'Definições da grelha': 'Grid settings',
    'Editar projeto': 'Edit project',
    'A guardar…': 'Saving…',
    'Guarda os teus projetos localmente e exporta uma cópia quando precisares de mudar de dispositivo.': 'Keep projects on your device and export a copy when you need to move to another device.',
    'Licença Pro não verificada': 'Pro licence not verified',
    'Inicia sessão para restaurar a tua licença Pro.': 'Sign in to restore your Pro licence.',
    'Não foi possível abrir o link. Tenta novamente.': 'Could not open the link. Try again.',

    'O Google recusou a configuração desta aplicação. Confirma no Firebase se o método Google está ativado e se o SHA-1/SHA-256 do certificado desta versão está registado na aplicação Android.': 'Google rejected this app configuration. In Firebase, enable the Google sign-in provider and register this Android release certificate\'s SHA-1/SHA-256 fingerprints.',
    'A configuração OAuth do Google está incompleta. Confirma o ID de cliente Web no Firebase e o fornecedor Google em Authentication.': 'Google OAuth is not fully configured. Check the Web client ID and the Google provider under Firebase Authentication.',
    'O Google não conseguiu estabelecer ligação. Verifica a internet e tenta novamente.': 'Google could not connect. Check your internet connection and try again.',
    'O início de sessão com Google falhou. Confirma a configuração do fornecedor Google no Firebase e tenta novamente.': 'Google sign-in failed. Check the Google provider configuration in Firebase and try again.',
    'O áudio associado ao projeto já não está disponível neste dispositivo. Importa-o novamente.': 'The project\'s audio file is no longer available on this device. Import it again.',
    'Não foi possível abrir o áudio guardado. Importa novamente um ficheiro compatível.': 'Could not open the saved audio. Import a compatible file again.',
    'Áudio aplicado ao projeto e guardado neste dispositivo.': 'Audio applied to the project and saved on this device.',
    'Não foi possível anexar o áudio ao projeto. Tenta novamente.': 'Could not attach the audio to the project. Try again.',
    'Áudio aplicado ao projeto': 'Audio applied to project',
    'Aplicar áudio ao projeto': 'Apply audio to project',
    'Reproduzir animação': 'Play animation',
    'Pausar animação': 'Pause animation',
    'Reproduzir áudio do projeto': 'Play project audio',
    'Pausar áudio do projeto': 'Pause project audio',
    'Pausar áudio': 'Pause audio',
    'Ouvir áudio': 'Listen to audio',
    'Remover áudio do projeto': 'Remove audio from project',
    'Adiciona pelo menos dois frames para reproduzir a animação.': 'Add at least two frames to play the animation.',
    'Não foi possível reproduzir o áudio deste projeto. Abre Áudio e importa o ficheiro novamente.': 'Could not play this project\'s audio. Open Audio and import the file again.',
    'A exportar o projeto': 'Exporting project',
    'A preparar a exportação…': 'Preparing export…',
    'A desenhar o frame…': 'Rendering frame…',
    'A guardar o ficheiro no dispositivo…': 'Saving file to device…',
    'Concluído! Ficheiro guardado no dispositivo.': 'Done! File saved on device.',
    'Exportação concluída. Ficheiro guardado automaticamente em Downloads/AnimPro ou na pasta de imagens/vídeos AnimPro.': 'Export complete. The file was saved automatically to Downloads/AnimPro or the AnimPro pictures/videos folder.',
    'Partilhar ficheiro guardado': 'Share saved file',
    'Guarda o frame atual como imagem PNG no dispositivo.': 'Save the current frame as a PNG image on your device.',
    'Guarda todos os frames como ficheiros PNG dentro de um ZIP.': 'Save all frames as PNG files in a ZIP archive.',
    'O ficheiro será criado a partir dos frames do projeto e guardado automaticamente no dispositivo.': 'The file will be created from the project\'s frames and automatically saved on your device.',
    'A exportação fica guardada no dispositivo. Usa o botão Partilhar depois de concluída para enviar o ficheiro.': 'The export is saved on your device. Use the Share button when it finishes to send the file.',

    'Não foi possível guardar o ficheiro no dispositivo.': 'Could not save the file to your device.',
    'Não foi possível abrir o destino da exportação.': 'Could not open the export destination.',
    'O Android não confirmou a gravação do ficheiro.': 'Android did not confirm that the file was saved.',
    'O ficheiro exportado não existe ou está vazio.': 'The exported file does not exist or is empty.',
    'Verificação temporariamente indisponível': 'Verification temporarily unavailable',
    'Não foi possível consultar o estado da licença agora. O editor e as funções gratuitas continuam disponíveis; o servidor confirmará o estado ao abrir o checkout.': 'The license status could not be checked right now. The editor and free features remain available; the server will confirm status at checkout.',
    'A importar…': 'Importing…',
    'Limpar marcações': 'Clear markers',
    'Procurar assets…': 'Search assets…',
    'Personagens': 'Characters',
    'Natureza': 'Nature',
    'Objetos': 'Objects',
    'Todos': 'All',
    'Raposa simpática': 'Friendly fox',
    'Rosto expressivo': 'Expressive face',
    'Árvore': 'Tree',
    'Nuvem': 'Cloud',
    'Estrela': 'Star',
    'Coração': 'Heart',
    'Casa': 'House',
    'Robot de formas básicas': 'Simple-shape robot',
    'Robot Buddy': 'Robot Buddy',
    'Pincel': 'Brush',
    'Continuar para pagamento': 'Continue to payment',
    'Nota: o áudio está guardado no projeto, mas a exportação MP4 ainda não mistura a faixa de som.': 'Note: audio is saved with the project, but MP4 export does not yet mix in the soundtrack.',
    'O ficheiro foi criado, mas o Android não conseguiu guardá-lo nas pastas visíveis. Verifica o espaço disponível e tenta novamente.': 'The file was created, but Android could not save it to a shared folder. Check available storage and try again.',
    'Falha ao codificar MP4 neste dispositivo. Tenta uma resolução menor e 12/24 FPS, ou exporta GIF.': 'MP4 encoding failed on this device. Try a lower resolution and 12/24 FPS, or export a GIF.',
    'Não foi possível exportar o ficheiro. Verifica o espaço disponível e tenta novamente.': 'Could not export the file. Check available storage and try again.',
    'Exportação a 60 FPS': '60 FPS export',
    'Licença permanente ativa': 'Lifetime license active',
    'Comprar permanentemente': 'Buy lifetime',
    '/ mês': '/ month',
    'pagamento único': 'one-time payment',
    'A tua sessão expirou. Entra novamente na tua conta.': 'Your session expired. Sign in again.',
    'Não foi possível iniciar esta compra. Seleciona um plano e tenta novamente.': 'Could not start this purchase. Select a plan and try again.',
    'As compras estão temporariamente indisponíveis. Tenta novamente mais tarde.': 'Purchases are temporarily unavailable. Try again later.',
    'Inicia sessão ou cria uma conta antes de comprar.': 'Sign in or create an account before purchasing.',
    'Conclui o pagamento no PayPal e regressa aqui. A licença é ativada pelo servidor depois da confirmação.': 'Complete payment with PayPal and return here. The server activates the license after confirmation.',
    'O PayPal não devolveu um link de pagamento válido.': 'PayPal did not return a valid payment link.',
    'Não foi possível iniciar o pagamento. Tenta novamente.': 'Could not start the payment. Try again.',
    'Geral': 'General',
    'E-mail de verificação enviado. Consulta a caixa de entrada e o spam.': 'Verification email sent. Check your inbox and spam folder.',
    'A entrada com Google está temporariamente indisponível. Podes usar o e-mail ou tentar mais tarde.': 'Google sign-in is temporarily unavailable. You can use email or try again later.',
    'O endereço de e-mail não é válido.': 'The email address is invalid.',
    'Este e-mail já tem uma conta. Experimenta iniciar sessão.': 'An account already exists for this email. Try signing in.',
    'A palavra-passe é demasiado fraca. Usa pelo menos 6 caracteres.': 'The password is too weak. Use at least 6 characters.',
    'E-mail ou palavra-passe incorretos.': 'Incorrect email or password.',
    'Este método de entrada está temporariamente indisponível. Tenta outra opção.': 'This sign-in method is temporarily unavailable. Try another option.',
    'Operação cancelada.': 'Operation cancelled.',
    'A animação será reproduzida sem áudio. Não foi possível abrir a faixa do projeto.': 'Animation will play without audio. The project\'s soundtrack could not be opened.',
    'O início de sessão falhou. Confirma a configuração do fornecedor Google no Firebase e tenta novamente.': 'Sign-in failed. Check the Google provider configuration in Firebase and try again.',
    'A licença está indisponível, mas as funções gratuitas continuam abertas.': 'The license service is unavailable, but free features remain accessible.',
    'A faixa de áudio está aplicada ao projeto.': 'The soundtrack is attached to the project.',
    'Não foi possível guardar o projeto. Tenta novamente.': 'Could not save the project. Try again.',
    'O codificador Android não criou um MP4 válido.': 'The Android encoder did not create a valid MP4.',
    'O dispositivo não conseguiu codificar o MP4. Tenta 540p/360p e 12 ou 24 FPS, ou exporta GIF.': 'The device could not encode MP4. Try 540p/360p at 12 or 24 FPS, or export a GIF.',
    'A tua licença Pro está ativa.': 'Your Pro license is active.',
    'A licença Pro já está ativa.': 'The Pro license is already active.',
    'O editor e as ferramentas gratuitas continuam disponíveis.': 'The editor and free tools remain available.',
    'O Google não devolveu um ID token.': 'Google did not return an ID token.',
    'Sessão iniciada com sucesso.': 'Signed in successfully.',
    'Introduz primeiro o teu e-mail no campo acima.': 'Enter your email in the field above first.',
    'Ainda não foi detetada a verificação. Abre o link recebido por e-mail e tenta novamente.': 'Verification has not been detected yet. Open the link sent by email and try again.',
    'A conta está temporariamente indisponível.': 'The account service is temporarily unavailable.',
    'Pincel seleccionado': 'Selected brush',
    'Audio': 'Audio',
    'Os recursos gratuitos estão disponíveis mesmo sem iniciar sessão.': 'Free features are available even when signed out.',
    'A animação precisa de pelo menos dois frames.': 'The animation needs at least two frames.',
    'A licença Pro é necessária apenas para funções avançadas. O editor e as funções gratuitas continuam disponíveis.': 'The Pro license is only needed for advanced features. The editor and free features remain available.',
    'Personagem simples': 'Simple character',
    'Rosto com olhos e sorriso': 'Face with eyes and a smile',
    'Árvore e tronco': 'Tree and trunk',
    'Nuvem leve': 'Soft cloud',
    'Estrela de cinco pontas': 'Five-point star',
    'Coração desenhado': 'Drawn heart',
    'Casa com telhado': 'House with roof',
    'Ajuda': 'Help',
    'Personagem': 'Character',
    'Robot': 'Robot',
    'Desenha, experimenta poses, organiza os teus frames e exporta animações no Android.': 'Draw, experiment with poses, organize frames, and export animations on Android.',
    'O estado da licença é confirmado pelo servidor.': 'License status is confirmed by the server.',
    'O pagamento é processado de forma segura pelo PayPal.': 'Payment is processed securely by PayPal.',
    'A faixa de áudio está guardada no projeto, mas a exportação MP4 ainda não mistura a faixa de som.': 'The soundtrack is saved with the project, but MP4 export does not yet mix in the audio track.',
    'Selecionar tudo': 'Select all',
    'Aguardar…': 'Please wait…',
  };
}

/// Text widget that translates known UI strings while preserving Flutter's Text API.
/// Import this file and hide Flutter's Text symbol to use the bilingual wrapper.
class AppLocalizedText extends material.StatelessWidget {
  const AppLocalizedText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final double? textScaleFactor;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) {
    return material.Text(
      AppLocale.translate(context, data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler ??
          (textScaleFactor == null ? null : material.TextScaler.linear(textScaleFactor!)),
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

typedef Text = AppLocalizedText;
