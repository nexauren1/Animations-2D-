import 'package:flutter/material.dart';

/// Ecrã de boas-vindas mostrado na primeira abertura.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({required this.onContinue, super.key});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF201827);
    const orange = Color(0xFFFF7B2D);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1E9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: orange,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 9),
                  const Text('AnimPro',
                      style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  TextButton(
                    onPressed: onContinue,
                    child: const Text('Saltar', style: TextStyle(color: ink)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                flex: 5,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 255,
                      height: 255,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0xFFFFD4B5), Color(0xFFFFE9DB)],
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 25,
                      left: 28,
                      child: Icon(Icons.auto_awesome, color: Color(0xFFFFB878), size: 28),
                    ),
                    const Positioned(
                      bottom: 47,
                      right: 20,
                      child: Icon(Icons.star_rounded, color: Color(0xFFFFC168), size: 31),
                    ),
                    Container(
                      height: 194,
                      width: 194,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFAC57),
                        border: Border.all(color: const Color(0xFF572E24), width: 4),
                        borderRadius: BorderRadius.circular(62),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Positioned(
                            top: 29,
                            left: 35,
                            child: _EarShape(),
                          ),
                          const Positioned(
                            top: 29,
                            right: 35,
                            child: _EarShape(),
                          ),
                          Positioned(
                            top: 58,
                            left: 39,
                            child: Container(
                              width: 35,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: ink, width: 3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Align(
                                alignment: Alignment(0, -0.15),
                                child: CircleAvatar(radius: 8, backgroundColor: Color(0xFF263B58)),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 58,
                            right: 39,
                            child: Container(
                              width: 35,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: ink, width: 3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Align(
                                alignment: Alignment(0, -0.15),
                                child: CircleAvatar(radius: 8, backgroundColor: Color(0xFF263B58)),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 25,
                            child: Container(
                              width: 75,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0DA),
                                border: Border.all(color: ink, width: 3),
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                          ),
                          const Positioned(
                            bottom: 58,
                            child: Icon(Icons.circle, size: 16, color: ink),
                          ),
                          Positioned(
                            top: -3,
                            right: 4,
                            child: Transform.rotate(
                              angle: -.45,
                              child: Icon(Icons.brush_rounded, size: 53, color: Color(0xFF2D789D)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      bottom: 12,
                      left: 12,
                      child: _StepIllustration(icon: Icons.draw_rounded, color: Color(0xFFFFB65A)),
                    ),
                    const Positioned(
                      bottom: 1,
                      child: _StepIllustration(icon: Icons.hub_rounded, color: Color(0xFF8FB6EF)),
                    ),
                    const Positioned(
                      bottom: 12,
                      right: 12,
                      child: _StepIllustration(icon: Icons.play_arrow_rounded, color: Color(0xFFC2A0F6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Dá vida aos teus desenhos',
                textAlign: TextAlign.center,
                style: TextStyle(color: ink, fontSize: 29, height: 1.08, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                'Cria animações 2D em três passos simples.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF62535A), fontSize: 16),
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: _IntroStep(icon: Icons.edit_rounded, title: 'Desenha', subtitle: 'Esboça a personagem', tint: Color(0xFFFFD08D))),
                  SizedBox(width: 10),
                  Expanded(child: _IntroStep(icon: Icons.hub_rounded, title: 'Prepara', subtitle: 'Cria poses e camadas', tint: Color(0xFFBED8FF))),
                  SizedBox(width: 10),
                  Expanded(child: _IntroStep(icon: Icons.play_arrow_rounded, title: 'Anima', subtitle: 'Move frame a frame', tint: Color(0xFFDCC5FF))),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text('Começar  →', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Sem conta · Os projetos ficam no teu dispositivo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF75656A), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarShape extends StatelessWidget {
  const _EarShape();
  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 51,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0DA),
          border: Border.all(color: const Color(0xFF572E24), width: 3),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(22),
            bottom: Radius.circular(7),
          ),
        ),
      );
}

class _StepIllustration extends StatelessWidget {
  const _StepIllustration({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        height: 62,
        width: 62,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          boxShadow: const [BoxShadow(color: Color(0x1A4D2A36), blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: Center(
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 29, color: const Color(0xFF403148)),
          ),
        ),
      );
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0DFD8)),
        ),
        child: Column(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: const Color(0xFF3B3450), size: 27),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Color(0xFF201827), fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5D5158), fontSize: 10, height: 1.2)),
          ],
        ),
      );
}
