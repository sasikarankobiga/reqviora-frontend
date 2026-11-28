import '../../../core/network/api_client.dart';

class RegistrationResult {
  const RegistrationResult({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.verificationEmailSent,
  });

  final String userId;
  final String email;
  final String displayName;
  final bool emailVerified;
  final bool verificationEmailSent;

  factory RegistrationResult.fromJson(Map<Object?, Object?> json) {
    final userId = json['userId'];
    final email = json['email'];
    final displayName = json['displayName'];
    final emailVerified = json['emailVerified'];
    final verificationEmailSent = json['verificationEmailSent'];

    final validUserId =
        userId is String &&
        RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        ).hasMatch(userId);
    final validEmail =
        email is String &&
        email.trim() == email &&
        email.length <= 320 &&
        email.contains('@');
    final validDisplayName =
        displayName is String &&
        displayName.trim() == displayName &&
        displayName.isNotEmpty;

    if (!validUserId ||
        !validEmail ||
        !validDisplayName ||
        emailVerified is! bool ||
        verificationEmailSent is! bool) {
      throw const ApiException(502, 'Invalid registration response.');
    }

    return RegistrationResult(
      userId: userId,
      email: email,
      displayName: displayName,
      emailVerified: emailVerified,
      verificationEmailSent: verificationEmailSent,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RegistrationResult &&
      other.userId == userId &&
      other.email == email &&
      other.displayName == displayName &&
      other.emailVerified == emailVerified &&
      other.verificationEmailSent == verificationEmailSent;

  @override
  int get hashCode => Object.hash(
    userId,
    email,
    displayName,
    emailVerified,
    verificationEmailSent,
  );
}
