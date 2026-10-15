import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const _site = 'https://nexauren1.github.io/Animations-2D-/';
  static const _links = <(IconData, String, String, String)>[
    (Icons.language_rounded, 'Site oficial', 'Apresentação, novidades e acesso às versões.', _site),
    (Icons.privacy_tip_outlined, 'Política de Privacidade', 'Dados locais, Firebase e serviços externos.', '${_site}privacy.html'),
    (Icons.description_outlined, 'Termos de Utilização', 'Condições de utilização e planos Pro.', '${_site}terms.html'),
    (Icons.support_agent_rounded, 'Suporte e problemas', 'Comunica um problema no repositório do projeto.', 'https://github.com/nexauren1/Animations-2D-/issues'),
    (Icons.download_rounded, 'Downloads oficiais', 'Consulta as versões publicadas do AnimPro.', 'https://github.com/nexauren1/Animations-2D-/releases'),
  ];

  Future<void> _open(BuildContext context, String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir a página. Verifica a ligação à internet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Informações e privacidade')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF332B6E), Color(0xFF191B2B)],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.play_circle_fill_rounded, size: 42, color: Color(0xFFA99BFF)),
                  SizedBox(height: 12),
                  Text('AnimPro', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text('Editor de animação 2D para Android. Consulta a informação oficial, as regras de privacidade e os termos antes de usar serviços externos ou comprar uma licença.',
                      style: TextStyle(color: Colors.white70, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ..._links.map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: const Color(0xFF191B2B),
                  child: ListTile(
                    leading: Icon(item.$1, color: const Color(0xFFA99BFF)),
                    title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(item.$3),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _open(context, item.$4),
                  ),
                )),
            const SizedBox(height: 12),
            const Text(
              'Importante: o acesso Pro é ativado apenas após a confirmação do pagamento pelo servidor. Não partilhes palavras-passe, chaves privadas ou dados financeiros em pedidos públicos de suporte.',
              style: TextStyle(color: Colors.white54, height: 1.45, fontSize: 12),
            ),
          ],
        ),
      );
}
