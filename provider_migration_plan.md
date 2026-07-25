# Provider Migration Plan

## Current state
- Migration completed: each active feature has its own ChangeNotifier provider.
- AppState has been removed; no screen reads global state from it.

## Provider ownership
1. ThemeProvider: dark-mode state and theme switching.
2. LanguageProvider: locale and localized strings.
3. ReminderProvider: eye-break interval and active reminder state.
4. SettingsProvider: units, time format, and notification preferences.
5. HabitProvider: habits, progress, targets, survey, charts, and eye-break count.
6. ChatProvider: chat messages, typing state, and greeting state.
7. AuthProvider: the isolated authentication boundary. No auth feature existed to migrate, so it intentionally contains no fabricated session behavior.

## Guardrails
- Do not rewrite unrelated code.
- Do not introduce duplicate state.
- Keep existing behavior intact after every step.
- Keep auth integration (Firebase, login/logout, guardian email) inside AuthProvider when that feature is introduced.
