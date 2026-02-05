// lib/core/config.dart
class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  // Timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);


  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY');


  // Optional: GitHub Token for AI (if you want AI chat)
  static const String githubToken =
      String.fromEnvironment('GITHUB_TOKEN');




  static const List<String> geminiModels = [
  'gemini-1.0-pro',
];
}


  