class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final AuthProvider provider;
  final String? photoUrl;

  AuthUser copyWith({
    String? id,
    String? email,
    String? displayName,
    AuthProvider? provider,
    String? photoUrl,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      provider: provider ?? this.provider,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'display_name': displayName,
      'provider': provider.name,
      'photo_url': photoUrl,
    };
  }

  static AuthUser? fromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final id = _readNonEmptyString(raw['id']);
    final email = _readNonEmptyString(raw['email']);
    final displayName = _readNonEmptyString(raw['display_name']);
    final providerName = _readNonEmptyString(raw['provider']);
    final provider = AuthProviderX.fromName(providerName);

    if (id == null || email == null || displayName == null || provider == null) {
      return null;
    }

    return AuthUser(
      id: id,
      email: email,
      displayName: displayName,
      provider: provider,
      photoUrl: _readNonEmptyString(raw['photo_url']),
    );
  }
}

enum AuthProvider {
  password,
  google,
}

extension AuthProviderX on AuthProvider {
  static AuthProvider? fromName(String? raw) {
    return switch (raw) {
      'password' => AuthProvider.password,
      'google' => AuthProvider.google,
      _ => null,
    };
  }
}

String? _readNonEmptyString(dynamic value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
