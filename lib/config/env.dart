class Env {
  static const nimApiKey = String.fromEnvironment(
    'NIM_API_KEY',
    defaultValue: '',
  );
}