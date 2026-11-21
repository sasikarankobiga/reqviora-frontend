
class AuthSession {
  final String userId;
  final String email;
  final String displayName;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final String tokenType;

  const AuthSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.tokenType,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: json['userId'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      accessToken: json['accessToken'] as String,
      accessTokenExpiresAt: DateTime.parse(
        json['accessTokenExpiresAt'] as String,
      ),
      refreshToken: json['refreshToken'] as String,
      refreshTokenExpiresAt: DateTime.parse(
        json['refreshTokenExpiresAt'] as String,
      ),
      tokenType: (json['tokenType'] as String?) ?? 'Bearer',
    );
  }

  bool get isAccessTokenExpired {
    return DateTime.now().toUtc().isAfter(
      accessTokenExpiresAt.toUtc(),
    );
  }
}
