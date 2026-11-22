import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../application/auth_providers.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .authenticate(email.text.trim(), password.text, register: register);
      if (mounted) context.go('/projects');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (MediaQuery.sizeOf(context).width > 850)
                  Expanded(
                    child: Container(
                      height: 540,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF292051), Color(0xFF725AE5)],
                        ),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                          SizedBox(height: 26),
                          Text(
                            'REQVIORA',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'From requirements to reality.',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE7E1FF),
                            ),
                          ),
                          Spacer(),
                          Text(
                            'Capture ideas. Map experiences. Design with confidence.\nDeliver a traceable Second Brain.',
                            style: TextStyle(
                              color: Colors.white,
                              height: 1.6,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 26),
                Expanded(
                  child: SurfaceCard(
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            register ? 'Create your workspace' : 'Welcome back',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'Secure project-scoped access',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 26),
                          TextFormField(
                            controller: email,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator:
                                (s) =>
                                    s == null || !s.contains('@')
                                        ? 'Enter a valid email'
                                        : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: password,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                            validator:
                                (s) =>
                                    s == null || s.length < 12
                                        ? 'Use at least 12 characters'
                                        : null,
                          ),
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: busy ? null : submit,
                            child: Text(
                              busy
                                  ? 'Connecting…'
                                  : register
                                  ? 'Create account'
                                  : 'Sign in',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed:
                                busy
                                    ? null
                                    : () => setState(() {
                                      register = !register;
                                      error = null;
                                    }),
                            child: Text(
                              register
                                  ? 'Already have an account? Sign in'
                                  : 'Need an account? Register',
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 9),
                            InlineError(error!),
                          ],
                          const SizedBox(height: 16),
                          const Text(
                            'Credentials and sessions are handled by the ASP.NET Core Identity API.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
