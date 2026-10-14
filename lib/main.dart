import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/project_model.dart';
import 'screens/home_screen.dart';
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
      home: HomeScreen(store: store),
    );
  }
}
