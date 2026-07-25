import 'package:flutter/foundation.dart';

/// Boundary for authentication state.
///
/// The current application has no Firebase configuration or existing
/// login, logout, guardian-email, or user-session flow to migrate. Keeping
/// this provider registered establishes a single ownership point without
/// inventing authentication behavior.
class AuthProvider extends ChangeNotifier {}
