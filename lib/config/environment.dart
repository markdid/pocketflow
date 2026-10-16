/// Selected with `--dart-define=ENV=dev|prod` (see Makefile and .vscode/launch.json).
enum Environment {
  development,
  production;

  static const Environment current = String.fromEnvironment('ENV', defaultValue: 'dev') == 'prod'
      ? Environment.production
      : Environment.development;

  static bool get isDevelopment => current == Environment.development;
  static bool get isProduction => current == Environment.production;
}
