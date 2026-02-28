import 'package:flutter/material.dart';

import 'app_preferences.dart';

enum ThemeChoice {
  system,
  light,
  dark,
}

enum AiSourceChoice {
  cloud,
  local,
}

ThemeChoice toThemeChoice(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => ThemeChoice.light,
    ThemeMode.dark => ThemeChoice.dark,
    ThemeMode.system => ThemeChoice.system,
  };
}

ThemeMode themeModeFromChoice(ThemeChoice choice) {
  return switch (choice) {
    ThemeChoice.system => ThemeMode.system,
    ThemeChoice.light => ThemeMode.light,
    ThemeChoice.dark => ThemeMode.dark,
  };
}

AiSourceChoice toAiSourceChoice(AiPlannerSource source) {
  return switch (source) {
    AiPlannerSource.cloud => AiSourceChoice.cloud,
    AiPlannerSource.localGemini => AiSourceChoice.local,
  };
}

AiPlannerSource plannerSourceFromChoice(AiSourceChoice choice) {
  return switch (choice) {
    AiSourceChoice.cloud => AiPlannerSource.cloud,
    AiSourceChoice.local => AiPlannerSource.localGemini,
  };
}
