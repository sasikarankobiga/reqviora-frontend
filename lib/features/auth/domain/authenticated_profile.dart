import 'package:characters/characters.dart';

class AuthenticatedProfile {
  const AuthenticatedProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    this.avatarUrl,
  });

  factory AuthenticatedProfile.fromJson(Map<String, dynamic> json) {
    final userId = (json['userId'] ?? json['id'])?.toString().trim() ?? '';
    final email = json['email']?.toString().trim() ?? '';
    final displayName = json['displayName']?.toString().trim() ?? '';
    final avatar = (json['avatarUrl'] ?? json['profileImageUrl'])?.toString();
    final avatarUri = avatar == null ? null : Uri.tryParse(avatar.trim());

    if (userId.isEmpty || email.isEmpty || displayName.isEmpty) {
      throw const FormatException('Invalid account profile response.');
    }

    return AuthenticatedProfile(
      userId: userId,
      email: email,
      displayName: displayName,
      emailVerified: json['emailVerified'] == true,
      avatarUrl:
          avatarUri != null &&
                  (avatarUri.scheme == 'https' || avatarUri.scheme == 'http') &&
                  avatarUri.host.isNotEmpty &&
                  avatarUri.userInfo.isEmpty
              ? avatarUri.toString()
              : null,
    );
  }

  final String userId;
  final String email;
  final String displayName;
  final bool emailVerified;
  final String? avatarUrl;

  String get initials => initialsForDisplayName(displayName);
}

String initialsForDisplayName(String displayName) {
  final words =
      displayName
          .trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();
  if (words.isEmpty) return '?';

  final selected = words.length == 1 ? words : [words.first, words.last];
  return selected.map((word) => word.characters.first).join().toUpperCase();
}

enum GreetingPeriod { morning, afternoon, evening, welcomeBack }

GreetingPeriod greetingPeriodAt(DateTime localTime) => switch (localTime.hour) {
  >= 5 && < 12 => GreetingPeriod.morning,
  >= 12 && < 17 => GreetingPeriod.afternoon,
  >= 17 && < 21 => GreetingPeriod.evening,
  _ => GreetingPeriod.welcomeBack,
};

DateTime nextGreetingBoundary(DateTime localTime) {
  final today = DateTime(localTime.year, localTime.month, localTime.day);
  final boundaries = <DateTime>[
    today.add(const Duration(hours: 5)),
    today.add(const Duration(hours: 12)),
    today.add(const Duration(hours: 17)),
    today.add(const Duration(hours: 21)),
    today.add(const Duration(days: 1, hours: 5)),
  ];
  return boundaries.firstWhere((boundary) => boundary.isAfter(localTime));
}
