import 'package:firebase_core/firebase_core.dart';

/// Firebase identifiers are supplied at build time through GitHub Actions
/// repository variables. They are configuration values, not signing secrets.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static const bool nativeAndroidConfig =
      bool.fromEnvironment('FIREBASE_NATIVE_CONFIG');

  static bool _initialized = false;
  static String? _initializationError;

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static bool get isInitialized => _initialized;
  static String? get initializationError => _initializationError;
  static bool get canUseGoogleSignIn =>
      _initialized &&
      (googleWebClientId.trim().isNotEmpty || nativeAndroidConfig);

  static List<String> get missingValues => nativeAndroidConfig
      ? const <String>[]
      : <String>[
          if (apiKey.isEmpty) 'FIREBASE_API_KEY',
          if (appId.isEmpty) 'FIREBASE_APP_ID',
          if (messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
          if (projectId.isEmpty) 'FIREBASE_PROJECT_ID',
        ];

  static Future<void> initialize() async {
    if (!isConfigured && !nativeAndroidConfig) return;
    try {
      if (Firebase.apps.isNotEmpty) {
        _initialized = true;
        return;
      }
      if (isConfigured) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: apiKey,
            appId: appId,
            messagingSenderId: messagingSenderId,
            projectId: projectId,
          ),
        );
      } else {
        // Android Gradle's Google Services plugin supplies native resources
        // from android/app/google-services.json in this build variant.
        await Firebase.initializeApp();
      }
      _initialized = true;
      _initializationError = null;
    } catch (_) {
      // Keep the local editor usable if the Firebase configuration is invalid.
      _initializationError =
          'Não foi possível iniciar o Firebase. Confirma google-services.json e as variáveis do projeto.';
      _initialized = false;
    }
  }
}
