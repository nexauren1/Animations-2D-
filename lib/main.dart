import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/project_model.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/project_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final documents = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [ProjectModelSchema],
    directory: documents.path,
  );
  final store = ProjectStore(isar);
  await store.load();
  runApp(AnimProApp(store: store));
}

class AnimProApp extends StatelessWidget {
  const AnimProApp({required this.store, super.key});
  final ProjectStore store;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0B0D18);
    return MaterialApp(
      title: 'AnimPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6957FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF191B2A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: _LaunchGate(store: store),
    );
  }
}


/// Decide se mostra o tutorial inicial ou abre os projetos.
class _LaunchGate extends StatefulWidget {
  const _LaunchGate({required this.store});
  final ProjectStore store;

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  bool? _completed;

  @override
  void initState() {
    super.initState();
    _readPreference();
  }

  Future<void> _readPreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _completed = preferences.getBool('animpro_onboarding_done') ?? false);
  }

  Future<void> _completeOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('animpro_onboarding_done', true);
    if (mounted) setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_completed == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF1E9),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF7B2D), size: 64),
              SizedBox(height: 14),
              Text('AnimPro', style: TextStyle(color: Color(0xFF201827), fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
    }
    if (!_completed!) {
      return OnboardingScreen(onContinue: _completeOnboarding);
    }
    return HomeScreen(store: widget.store);
  }
}
