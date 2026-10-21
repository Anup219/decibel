/// Centralized configuration for app backend and environment variables.
/// 
/// For privacy, security, and open-source distribution, production credentials
/// are excluded from source control.
/// 
/// Supply credentials at build/runtime using either:
/// 
/// 1. Command-line defines:
///    ```bash
///    flutter run \
///      --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///      --dart-define=SUPABASE_ANON_KEY=your-anon-key
///    ```
/// 
/// 2. Or using a local, git-ignored JSON file:
///    ```bash
///    flutter run --dart-define-from-file=.env.json
///    ```
class ApiConfig {
  ApiConfig._();

  // ---------------------------------------------------------------------------
  // Supabase Backend (Anonymous Telemetry & Cloud Sync)
  // ---------------------------------------------------------------------------
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}
