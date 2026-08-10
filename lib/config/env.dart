class Env {
  static const nimApiKey = String.fromEnvironment(
    'NIM_API_KEY',
    defaultValue: '',
  );

  static const commitHash = String.fromEnvironment(
    'COMMIT_HASH',
    defaultValue: '',
  );
}