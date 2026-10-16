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
