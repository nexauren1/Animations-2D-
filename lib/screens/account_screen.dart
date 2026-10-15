import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/firebase_bootstrap.dart';

Future<void>? _googleInitialization;

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _createAccount = true;
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFF8E3444) : null,
        ),
      );
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'O endereço de e-mail não é válido.';
        case 'email-already-in-use':
          return 'Este e-mail já tem uma conta. Experimenta iniciar sessão.';
        case 'weak-password':
          return 'A palavra-passe é demasiado fraca. Usa pelo menos 6 caracteres.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-mail ou palavra-passe incorretos.';
        case 'user-disabled':
          return 'Esta conta está desativada. Contacta o suporte.';
        case 'too-many-requests':
          return 'Houve demasiadas tentativas. Espera um pouco e tenta novamente.';
        case 'operation-not-allowed':
          return 'Este método de entrada está temporariamente indisponível. Tenta outra opção.';
        case 'network-request-failed':
          return 'Não foi possível ligar à internet. Verifica a ligação.';
        case 'account-exists-with-different-credential':
          return 'Já existe uma conta com este e-mail. Entra com o método original.';
        case 'requires-recent-login':
          return 'Por segurança, termina a sessão e entra novamente antes de repetir.';
        default:
          return 'Não foi possível concluir a operação. Tenta novamente.';
      }
    }
    final text = error.toString().toLowerCase();
    if (text.contains('cancel')) return 'Operação cancelada.';
    if (text.contains('network') || text.contains('socket')) {
      return 'Falha de ligação. Verifica a internet e tenta novamente.';
    }
    return 'Não foi possível concluir a operação. Verifica a ligação à internet e tenta novamente.';
  }

  Future<void> _runBusy(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await _runBusy(() async {
      final auth = FirebaseAuth.instance;
      if (_createAccount) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final displayName = _nameController.text.trim();
        if (displayName.isNotEmpty) {
          await credential.user?.updateDisplayName(displayName);
          await credential.user?.reload();
        }
        await credential.user?.sendEmailVerification();
        _message('Conta criada. Enviámos um e-mail para verificar o endereço.');
      } else {
        await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        _message('Sessão iniciada com sucesso.');
      }
    });
  }

  Future<void> _signInGoogle() async {
    if (!FirebaseBootstrap.canUseGoogleSignIn) {
      _message(
        'A entrada com Google está temporariamente indisponível. Podes usar o e-mail ou tentar mais tarde.',
        error: true,
      );
      return;
    }

    await _runBusy(() async {
      final clientId = FirebaseBootstrap.googleWebClientId.trim();
      final initialization = _googleInitialization ??=
          GoogleSignIn.instance.initialize(
        // Android can read this value from google-services.json. Passing an
        // empty string overrides that configuration, so use null when absent.
        serverClientId: clientId.isEmpty ? null : clientId,
      );
      try {
        await initialization;
      } catch (_) {
        // Allow a later tap to retry if the first initialization failed.
        _googleInitialization = null;
        rethrow;
      }
      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('O Google não devolveu um ID token.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
      _message('Sessão iniciada com Google.');
    });
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _message('Introduz primeiro o teu e-mail no campo acima.');
      return;
    }
    await _runBusy(() async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _message(
        'Se existir uma conta para este endereço, receberás um e-mail para redefinir a palavra-passe.',
      );
    });
  }

  Future<void> _sendVerification(User user) async {
    await _runBusy(() async {
      await user.sendEmailVerification();
      _message('E-mail de verificação enviado. Consulta a caixa de entrada e o spam.');
    });
  }

  Future<void> _refreshVerification(User user) async {
    await _runBusy(() async {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser?.emailVerified == true) {
        _message('E-mail verificado com sucesso.');
      } else {
        _message(
          'Ainda não foi detetada a verificação. Abre o link recebido por e-mail e tenta novamente.',
          error: true,
        );
      }
    });
  }

  Future<void> _signOut() async {
    await _runBusy(() async {
      await FirebaseAuth.instance.signOut();
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase session has already been closed.
      }
      _message('Sessão terminada. Os projetos locais continuam neste telefone.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conta AnimPro')),
      body: SafeArea(
        child: !FirebaseBootstrap.isInitialized
            ? _buildSetupRequired()
            : StreamBuilder<User?>(
                stream: FirebaseAuth.instance.userChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final user = snapshot.data;
                  if (user != null) return _buildProfile(user);
                  return _buildSignIn();
                },
              ),
      ),
    );
  }

  Widget _buildSetupRequired() {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 18),
        const Icon(Icons.cloud_off_rounded, size: 64, color: Color(0xFF8F82FF)),
        const SizedBox(height: 18),
        const Text(
          'As contas online ainda não estão disponíveis',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text(
          'Podes continuar a desenhar, animar e guardar os teus projetos neste dispositivo. A entrada com conta estará disponível quando o serviço for ativado.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF202237),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFB9B0FF)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Os projetos locais continuam guardados no teu telefone. Não precisas de criar uma conta para usar o editor.',
                  style: TextStyle(height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignIn() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
      children: [
        Container(
          height: 72,
          width: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6555F5), Color(0xFF8D50E8)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.animation_rounded, size: 38, color: Colors.white),
        ),
        const SizedBox(height: 18),
        Text(
          _createAccount ? 'Cria a tua conta' : 'Bem-vindo de volta',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          _createAccount
              ? 'Cria um perfil AnimPro com Google ou e-mail.'
              : 'Entra na tua conta AnimPro.',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _busy || !FirebaseBootstrap.canUseGoogleSignIn
                ? null
                : _signInGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
            label: const Text('Continuar com Google'),
          ),
        ),
        if (!FirebaseBootstrap.canUseGoogleSignIn) ...[
          const SizedBox(height: 7),
          const Text(
            'A entrada com Google está temporariamente indisponível. Podes usar o e-mail.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
        const SizedBox(height: 18),
        const Row(children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('ou com e-mail', style: TextStyle(color: Colors.white54)),
          ),
          Expanded(child: Divider()),
        ]),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(
            children: [
              if (_createAccount) ...[
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome (opcional)',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 50,
                ),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Introduz um e-mail válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _hidePassword,
                textInputAction: _createAccount
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: _createAccount
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                onFieldSubmitted: (_) {
                  if (!_createAccount) _submitEmail();
                },
                decoration: InputDecoration(
                  labelText: 'Palavra-passe',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(_hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  ),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) return 'Introduz a palavra-passe.';
                  if (_createAccount && password.length < 6) {
                    return 'Usa pelo menos 6 caracteres.';
                  }
                  return null;
                },
              ),
              if (_createAccount) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _hideConfirm,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Confirmar palavra-passe',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                      icon: Icon(_hideConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Confirma a palavra-passe.';
                    if (value != _passwordController.text) {
                      return 'As palavras-passe não coincidem.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _submitEmail,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_createAccount ? 'Criar conta' : 'Iniciar sessão'),
                ),
              ),
            ],
          ),
        ),
        if (!_createAccount)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _resetPassword,
              child: const Text('Esqueci-me da palavra-passe'),
            ),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _createAccount = !_createAccount;
                    _confirmController.clear();
                  }),
          child: Text(
            _createAccount
                ? 'Já tens conta? Iniciar sessão'
                : 'Ainda não tens conta? Criar conta',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'A conta não substitui uma cópia de segurança. Nesta versão, os projetos ficam guardados neste dispositivo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildProfile(User user) {
    final name = user.displayName?.trim();
    final email = user.email ?? 'Sem e-mail associado';
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: const Color(0xFF6555F5),
          backgroundImage: user.photoURL == null ? null : NetworkImage(user.photoURL!),
          child: user.photoURL == null
              ? Text(
                  (name?.isNotEmpty == true ? name![0] : email[0]).toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          (name?.isNotEmpty == true) ? name! : 'Conta AnimPro',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(email, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  user.emailVerified ? Icons.verified_user_rounded : Icons.mark_email_unread_outlined,
                  color: user.emailVerified ? Colors.greenAccent : Colors.amber,
                ),
                title: Text(user.emailVerified ? 'E-mail verificado' : 'E-mail por verificar'),
                subtitle: user.emailVerified
                    ? const Text('O endereço foi confirmado.')
                    : const Text('Confirma o endereço para proteger a conta.'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Verificar novamente',
                      onPressed:
                          _busy ? null : () => _refreshVerification(user),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    if (!user.emailVerified)
                      IconButton(
                        tooltip: 'Enviar verificação',
                        onPressed: _busy ? null : () => _sendVerification(user),
                        icon: const Icon(Icons.send_rounded),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.phone_android_rounded),
                title: Text('Projetos neste dispositivo'),
                subtitle: Text('A conta não move automaticamente os ficheiros para a nuvem.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _busy ? null : _signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Terminar sessão'),
        ),
      ],
    );
  }
}
