enum AppEnvironment { production, staging, development }

class AppEnvironmentConfig {
  const AppEnvironmentConfig._();

  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  static AppEnvironment get current {
    switch (_rawEnv.toLowerCase()) {
      case 'staging':
        return AppEnvironment.staging;
      case 'development':
      case 'dev':
        return AppEnvironment.development;
      case 'production':
      case 'prod':
      default:
        return AppEnvironment.production;
    }
  }

  static String get environmentName {
    switch (current) {
      case AppEnvironment.staging:
        return 'staging';
      case AppEnvironment.development:
        return 'development';
      case AppEnvironment.production:
        return 'production';
    }
  }

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String supabaseRedirectUrl = String.fromEnvironment(
    'SUPABASE_REDIRECT_URL',
  );

  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}