import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart' hide Text;
import '../services/app_locale.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firebase_bootstrap.dart';
import 'account_screen.dart';

class _CheckoutException implements Exception {
  const _CheckoutException(this.message);

  final String message;
}

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key, this.requiredFeature});

  final String? requiredFeature;

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _launching = false;

  static const _site = 'https://nexauren1.github.io/Animations-2D-/';
  static const _checkoutEndpoint =
      'https://animations2d.nexaurenstore.workers.dev/api/checkout';
  static const _privacy = '${_site}privacy.html';
  static const _terms = '${_site}terms.html';

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFF963D4A) : null,
      ),
    );
  }

  Future<void> _openAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
    );
    // Refresh the account and entitlement stream after returning from sign-in.
    if (mounted) setState(() {});
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.parse(value);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _message('Não foi possível abrir o link. Tenta novamente.', error: true);
    }
  }

  Future<void> _buy(String plan) async {
    if (!FirebaseBootstrap.isInitialized || Firebase.apps.isEmpty) {
      _message(
        'As compras estão temporariamente indisponíveis. Tenta novamente mais tarde.',
        error: true,
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message('Inicia sessão ou cria uma conta antes de comprar.', error: true);
      await _openAccount();
      return;
    }
    if (_launching) return;
    setState(() => _launching = true);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw const _CheckoutException('Inicia sessão novamente antes de comprar.');
      }

      final request = await client
          .postUrl(Uri.parse(_checkoutEndpoint))
          .timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ' + idToken);
      request.write(jsonEncode(<String, String>{'plan': plan}));

      final response = await request.close().timeout(const Duration(seconds: 45));
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 30));
      Map<String, dynamic> data = <String, dynamic>{};
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // The server may return plain text for an unexpected gateway error.
      }

      if (response.statusCode != HttpStatus.ok) {
        final message = switch (response.statusCode) {
          HttpStatus.unauthorized || HttpStatus.forbidden =>
            'A tua sessão expirou. Entra novamente na tua conta.',
          HttpStatus.conflict =>
            'A tua licença Pro já está ativa. Não precisas de comprar novamente.',
          HttpStatus.badRequest =>
            'Não foi possível iniciar esta compra. Seleciona um plano e tenta novamente.',
          HttpStatus.tooManyRequests =>
            'Houve demasiadas tentativas. Espera um pouco antes de voltar a tentar.',
          HttpStatus.badGateway ||
          HttpStatus.serviceUnavailable ||
          HttpStatus.internalServerError =>
            'As compras estão temporariamente indisponíveis. Tenta novamente mais tarde.',
          _ => 'Não foi possível iniciar o pagamento. Tenta novamente.',
        };
        throw _CheckoutException(message);
      }

      final approval = data['approvalUrl'] as String?;
      final url = approval == null ? null : Uri.tryParse(approval);
      final safePayPalHost = url != null &&
          (url.host == 'paypal.com' || url.host.endsWith('.paypal.com'));
      if (url == null ||
          !url.hasAuthority ||
          url.scheme != 'https' ||
          !safePayPalHost) {
        throw const _CheckoutException(
          'O PayPal não devolveu um link de pagamento válido.',
        );
      }

      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const _CheckoutException(
          'Não foi possível abrir a página segura do PayPal.',
        );
      }
      if (mounted) {
        _message(
          'Conclui o pagamento no PayPal e regressa aqui. A licença é ativada pelo servidor depois da confirmação.',
        );
      }
    } on _CheckoutException catch (error) {
      _message(error.message, error: true);
    } catch (_) {
      _message(
        'Não foi possível iniciar o pagamento. Verifica a ligação à internet e tenta novamente.',
        error: true,
      );
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _launching = false);
    }
  }

  bool _isEntitled(Map<String, dynamic>? data) {
    if (data == null || data['active'] != true) return false;
    final expires = data['expiresAt'];
    if (data['type'] == 'lifetime' && expires == null) return true;
    if (expires is Timestamp) return expires.toDate().isAfter(DateTime.now());
    if (expires is DateTime) return expires.isAfter(DateTime.now());
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final firebaseReady = FirebaseBootstrap.isInitialized && Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;
    final canReadEntitlement = firebaseReady && user != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AnimPro Pro'),
        actions: [
          IconButton(
            tooltip: 'Política de Privacidade',
            onPressed: () => _openLink(_privacy),
            icon: const Icon(Icons.shield_outlined),
          ),
          IconButton(
            tooltip: 'Termos de Utilização',
            onPressed: () => _openLink(_terms),
            icon: const Icon(Icons.description_outlined),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: canReadEntitlement
            ? FirebaseFirestore.instance
                .collection('proEntitlements')
                .doc(user.uid)
                .snapshots()
            : null,
        builder: (context, snapshot) {
          final entitlementPending = canReadEntitlement && !snapshot.hasData && !snapshot.hasError;
          final entitlementUnavailable = canReadEntitlement && snapshot.hasError;
          final purchasesBlocked = entitlementPending;
          final data = snapshot.data?.data();
          final active = _isEntitled(data);
          final planName = data?['type'] == 'lifetime'
              ? 'Pro permanente'
              : 'Pro ativo';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3E347F), Color(0xFF171B30)],
                  ),
                  border: Border.all(color: const Color(0xFF7165C8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        size: 44, color: Color(0xFFFFD36A)),
                    const SizedBox(height: 14),
                    const Text(
                      'Cria sem limites criativos',
                      style: TextStyle(fontSize: 28, height: 1.08, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.requiredFeature == null
                          ? 'Desbloqueia ferramentas avançadas de animação com o AnimPro Pro.'
                          : '${widget.requiredFeature} faz parte do AnimPro Pro. Escolhe um plano para desbloquear este recurso.',
                      style: const TextStyle(color: Colors.white70, height: 1.45),
                    ),
                    if (active) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C6B53),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 18),
                            const SizedBox(width: 8),
                            Text(planName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('O que está incluído',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text(
                'O desenho, os efeitos visuais, o áudio e a exportação MP4 continuam gratuitos. O Pro desbloqueia apenas ferramentas avançadas.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 14),
              const _ProFeature(
                icon: Icons.brush_rounded,
                title: 'Pincéis avançados',
                detail: 'Desbloqueia aerógrafo, pincel suave, pastel, pincel seco, pixel e efeitos de traço Pro.',
              ),
              const _ProFeature(
                icon: Icons.hub_outlined,
                title: 'Rigging e poses',
                detail: 'Ajusta poses com controlos de rigging e guarda-as como frames.',
              ),
              const _ProFeature(
                icon: Icons.high_quality_rounded,
                title: 'Exportação a 1080p',
                detail: 'Exporta vídeo em alta resolução para trabalhos finais.',
              ),
              const _ProFeature(
                icon: Icons.movie_creation_outlined,
                title: 'GIF e sequência PNG',
                detail: 'Desbloqueia formatos avançados para partilhar ou continuar a edição noutros programas.',
              ),
              const _ProFeature(
                icon: Icons.speed_rounded,
                title: 'Exportação até 60 FPS',
                detail: 'Controla a fluidez da animação em exportações de vídeo.',
              ),
              const SizedBox(height: 22),
              if (user == null) ...[
                const Text(
                  'Para associar a compra à tua licença, inicia sessão ou cria uma conta AnimPro. Os teus projetos locais continuam no dispositivo.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _openAccount,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Entrar ou criar conta'),
                  ),
                ),
              ] else ...[
                if (entitlementUnavailable) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF332B20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF6D5934)),
                    ),
                    child: const Text(
                      'Não foi possível consultar a licença neste momento. As ferramentas gratuitas continuam disponíveis. Podes tentar a compra; o servidor volta a verificar a licença antes de processar o pagamento.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ),
                ],
                _PlanCard(
                  title: 'Pro Mensal',
                  price: r'$5',
                  cadence: '/ mês',
                  description: 'Acesso Pro enquanto a subscrição estiver ativa.',
                  buttonLabel: entitlementPending
                      ? 'A verificar licença…'
                      : active && data?['type'] == 'monthly'
                          ? 'Subscrição ativa'
                          : 'Assinar mensalmente',
                  recommended: true,
                  busy: _launching,
                  disabled: purchasesBlocked || (active && data?['type'] == 'monthly'),
                  onPressed: () => _buy('monthly'),
                ),
                const SizedBox(height: 12),
                _PlanCard(
                  title: 'Pro Permanente',
                  price: r'$50',
                  cadence: 'pagamento único',
                  description: 'Uma compra, acesso vitalício à versão Pro atual e às funcionalidades Pro incluídas.',
                  buttonLabel: entitlementPending
                      ? 'A verificar licença…'
                      : active && data?['type'] == 'lifetime'
                          ? 'Licença permanente ativa'
                          : 'Comprar permanentemente',
                  busy: _launching,
                  disabled: purchasesBlocked || (active && data?['type'] == 'lifetime'),
                  onPressed: () => _buy('lifetime'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'O plano mensal renova-se automaticamente até ser cancelado no PayPal. O plano permanente é uma compra única, não uma subscrição anual. Confirma o preço final e as condições no checkout antes de pagar.',
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.45),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 18,
                runSpacing: 10,
                children: [
                  TextButton(
                    onPressed: () => _openLink(_site),
                    child: const Text('Site oficial'),
                  ),
                  TextButton(
                    onPressed: () => _openLink(_privacy),
                    child: const Text('Privacidade'),
                  ),
                  TextButton(
                    onPressed: () => _openLink(_terms),
                    child: const Text('Termos'),
                  ),
                ],
              ),
              if (snapshot.hasError)
                const Text(
                  'Não foi possível atualizar o estado Pro. Verifica a ligação ao Firestore.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProFeature extends StatelessWidget {
  const _ProFeature({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF272442),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: const Color(0xFFB9AEFF)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(detail, style: const TextStyle(color: Colors.white60, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.cadence,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    required this.busy,
    this.recommended = false,
    this.disabled = false,
  });

  final String title;
  final String price;
  final String cadence;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool busy;
  final bool recommended;
  final bool disabled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF171A29),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: recommended ? const Color(0xFF8879FF) : const Color(0xFF33384F),
            width: recommended ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
                if (recommended)
                  const Icon(Icons.star_rounded, color: Color(0xFFFFD36A)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: const TextStyle(fontSize: 35, fontWeight: FontWeight.w900, height: 1)),
                const SizedBox(width: 8),
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(cadence, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                )),
              ],
            ),
            const SizedBox(height: 10),
            Text(description, style: const TextStyle(color: Colors.white60, height: 1.4)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: busy || disabled ? null : onPressed,
                child: busy
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(buttonLabel),
              ),
            ),
          ],
        ),
      );
}
