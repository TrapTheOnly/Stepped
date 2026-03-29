import '../../config/runtime_config.dart';

String? normalizeSocialAssetUrl(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  if (_looksLikeLocalPath(normalized)) {
    return normalized;
  }

  final parsed = Uri.tryParse(normalized);
  if (parsed != null) {
    final scheme = parsed.scheme.toLowerCase();
    if ((scheme == 'http' || scheme == 'https') &&
        parsed.host.trim().isNotEmpty) {
      return normalized;
    }
    if (scheme == 'file') {
      return normalized;
    }
  }

  if (normalized.startsWith('//')) {
    return 'https:$normalized';
  }

  final baseUri = Uri.parse(defaultSteppedApiBaseUrl);
  final relativePath =
      normalized.startsWith('/') ? normalized : '/$normalized';
  return baseUri.resolve(relativePath).toString();
}

bool _looksLikeLocalPath(String raw) {
  if (raw.startsWith(r'\\')) {
    return true;
  }
  if (RegExp(r'^[a-zA-Z]:\\').hasMatch(raw)) {
    return true;
  }
  if (raw.startsWith('./') || raw.startsWith('../')) {
    return true;
  }
  if (raw.startsWith(r'.\') || raw.startsWith(r'..\')) {
    return true;
  }
  return false;
}
