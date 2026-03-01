const _defaultSteppedApiBaseUrl = 'https://api.stepped.world';
const _defaultGeminiApiVersion = 'v1beta';
const _defaultGeminiModel = 'gemini-3-flash';
const _defaultGeminiFallbackModels = 'gemini-3.0-flash,gemini-3-flash-preview';

const _steppedApiBaseUrlFromEnv = String.fromEnvironment(
  'STEPPED_API_BASE_URL',
  defaultValue: _defaultSteppedApiBaseUrl,
);
const _geminiModelFromEnv = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: _defaultGeminiModel,
);
const _geminiFallbackModelsFromEnv = String.fromEnvironment(
  'GEMINI_MODEL_FALLBACKS',
  defaultValue: _defaultGeminiFallbackModels,
);
const _geminiApiVersionFromEnv = String.fromEnvironment(
  'GEMINI_API_VERSION',
  defaultValue: _defaultGeminiApiVersion,
);

String get defaultSteppedApiBaseUrl {
  final parsed = Uri.tryParse(_steppedApiBaseUrlFromEnv.trim());
  if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
    return _defaultSteppedApiBaseUrl;
  }
  return parsed.toString();
}

String get defaultGeminiApiVersion {
  final normalized = _geminiApiVersionFromEnv.trim();
  if (_isSupportedApiVersionFormat(normalized)) {
    return normalized;
  }
  return _defaultGeminiApiVersion;
}

List<String> get defaultGeminiModelCandidates {
  final seeded = <String>[
    _geminiModelFromEnv,
    ..._geminiFallbackModelsFromEnv.split(','),
    _defaultGeminiModel,
    ..._defaultGeminiFallbackModels.split(','),
  ];

  final orderedUnique = <String>[];
  final seen = <String>{};
  for (final entry in seeded) {
    final model = entry.trim();
    if (model.isEmpty) {
      continue;
    }
    final key = model.toLowerCase();
    if (!seen.add(key)) {
      continue;
    }
    orderedUnique.add(model);
  }
  return orderedUnique;
}

bool _isSupportedApiVersionFormat(String raw) {
  if (raw.isEmpty) {
    return false;
  }
  final pattern = RegExp(r'^v[0-9]+([a-z0-9._-]*)$');
  return pattern.hasMatch(raw.toLowerCase());
}
