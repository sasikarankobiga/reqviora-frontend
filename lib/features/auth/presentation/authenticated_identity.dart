import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/language_settings.dart';
import '../../../core/auth/auth_session.dart';
import '../application/auth_providers.dart';
import '../domain/authenticated_profile.dart';

class AuthenticatedAvatar extends ConsumerWidget {
  const AuthenticatedAvatar({super.key, this.radius = 17});

  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authSession.authenticated) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE8DFFF),
        child: const Icon(Icons.person_outline),
      );
    }
    final profile = ref.watch(authenticatedProfileProvider).value;
    final fallback = Text(
      profile?.initials ?? '?',
      maxLines: 1,
      style: TextStyle(fontSize: radius * .72, fontWeight: FontWeight.w800),
    );
    final url = profile?.avatarUrl;

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE8DFFF),
      foregroundColor: const Color(0xFF5B3CC4),
      child:
          url == null
              ? fallback
              : ClipOval(
                child: Image.network(
                  url,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(child: fallback),
                ),
              ),
    );
  }
}

class AuthenticatedName extends ConsumerWidget {
  const AuthenticatedName({super.key, this.fallback = 'Account'});

  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authSession.authenticated) return Text(fallback);
    final profile = ref.watch(authenticatedProfileProvider);
    return Text(
      profile.value?.displayName ?? fallback,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
  }
}

class PersonalizedGreeting extends ConsumerStatefulWidget {
  const PersonalizedGreeting({super.key, this.now = DateTime.now});

  final DateTime Function() now;

  @override
  ConsumerState<PersonalizedGreeting> createState() =>
      _PersonalizedGreetingState();
}

class _PersonalizedGreetingState extends ConsumerState<PersonalizedGreeting>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleBoundary();
  }

  void _scheduleBoundary() {
    _timer?.cancel();
    final now = widget.now();
    final delay = nextGreetingBoundary(now).difference(now);
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleBoundary();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleBoundary();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        authSession.authenticated
            ? ref.watch(authenticatedProfileProvider).value?.displayName
            : null;
    final period = greetingPeriodAt(widget.now());
    final greeting = switch (period) {
      GreetingPeriod.morning => uiText(context, 'Good morning', 'காலை வணக்கம்'),
      GreetingPeriod.afternoon => uiText(
        context,
        'Good afternoon',
        'மதிய வணக்கம்',
      ),
      GreetingPeriod.evening => uiText(context, 'Good evening', 'மாலை வணக்கம்'),
      GreetingPeriod.welcomeBack => uiText(
        context,
        'Welcome back',
        'மீண்டும் வரவேற்கிறோம்',
      ),
    };

    return Text(name == null ? '$greeting!' : '$greeting, $name!');
  }
}
