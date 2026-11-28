import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/language_settings.dart';
import '../../projects/application/projects_providers.dart';
import '../../projects/presentation/project_members_access.dart';
import '../data/billing_repository.dart';
import '../data/hosted_checkout.dart';
import '../domain/billing_models.dart';
import '../domain/hosted_checkout_port.dart';
import 'billing_checkout_dialog.dart';
import 'billing_widgets.dart';

final billingRepositoryProvider = Provider(
  (ref) => BillingRepository(ref.watch(apiClientProvider)),
);
final hostedCheckoutProvider = Provider<HostedCheckoutPort>(
  (_) => createHostedCheckout(),
);

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  ProjectPricing? _pricing;
  PaymentDetails? _status;
  var _history = const <PaymentDetails>[];
  bool _owner = false;
  bool _busy = true;
  String? _error;
  int _operation = 0;
  late int _generation;

  BillingRepository get _repository => ref.read(billingRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _generation = authSession.generation;
    authSession.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    super.dispose();
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) return;
    _generation = authSession.generation;
    setState(() {
      _operation++;
      _pricing = null;
      _status = null;
      _history = const [];
      _owner = false;
      _busy = false;
      _error = uiText(
        context,
        'Session changed. Return to projects.',
        'அமர்வு மாறியது. திட்டங்களுக்கு திரும்பவும்.',
      );
    });
  }

  String _message(Object failure) {
    if (failure is ApiException) {
      return switch (failure.statusCode) {
        401 => uiText(context, 'Sign in again.', 'மீண்டும் உள்நுழையவும்.'),
        403 => uiText(
          context,
          'Project access is required.',
          'திட்ட அணுகல் தேவை.',
        ),
        503 => uiText(
          context,
          'Billing is unavailable.',
          'கட்டணம் கிடைக்கவில்லை.',
        ),
        _ => uiText(
          context,
          'Billing information could not be loaded.',
          'கட்டண தகவலை ஏற்ற முடியவில்லை.',
        ),
      };
    }
    return uiText(
      context,
      'Billing response was invalid.',
      'கட்டண பதில் செல்லாது.',
    );
  }

  Future<void> _load() async {
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final members = await ref
          .read(projectMembersRepositoryProvider)
          .getMembers(widget.projectId);
      final actor = projectMemberActorId(authSession.token)?.toLowerCase();
      final pricing = await _repository.pricing(widget.projectId);
      PaymentDetails? status;
      try {
        status = await _repository.status(widget.projectId);
      } on ApiException catch (failure) {
        if (failure.statusCode != 404) rethrow;
      }
      final history = await _repository.history(widget.projectId);
      if (!mounted || operation != _operation) return;
      setState(() {
        _owner = members.any(
          (item) => item.isOwner && item.userId.toLowerCase() == actor,
        );
        _pricing = pricing;
        _status = status;
        _history = history.items;
      });
    } catch (failure) {
      if (mounted && operation == _operation) {
        setState(() => _error = _message(failure));
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  Future<void> _checkout() async {
    final pricing = _pricing;
    if (!_owner || pricing == null || !pricing.gatewayEnabled || _busy) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => BillingCheckoutDialog(
            projectId: widget.projectId,
            pricing: pricing,
            repository: _repository,
            hostedCheckout: ref.read(hostedCheckoutProvider),
          ),
    );
  }

  Future<void> _poll() async {
    if (_busy) return;
    final operation = ++_operation;
    final generation = authSession.generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      for (var attempt = 0; attempt < 8; attempt++) {
        final status = await _repository.status(widget.projectId);
        if (!mounted ||
            operation != _operation ||
            generation != authSession.generation) {
          return;
        }
        setState(() => _status = status);
        if (status.status.terminal) break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (mounted && operation == _operation) {
        final history = await _repository.history(widget.projectId);
        setState(() => _history = history.items);
      }
    } catch (failure) {
      if (mounted && operation == _operation) {
        setState(() => _error = _message(failure));
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pricing = _pricing;
    final status = _status;
    return AppShell(
      pageTitle: uiText(context, 'Project Billing', 'திட்ட கட்டணம்'),
      projectId: widget.projectId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiText(context, 'Billing & Entitlement', 'கட்டணம் மற்றும் உரிமை'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            uiText(
              context,
              'Payment redirects are informational. Access is granted only from backend-verified entitlement.',
              'கட்டண திருப்புகள் தகவலுக்காக மட்டுமே. சேவையகம் சரிபார்த்த உரிமையால் மட்டுமே அணுகல் வழங்கப்படும்.',
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (pricing != null)
            BillingPricingCard(
              pricing: pricing,
              checkoutEnabled:
                  _owner &&
                  pricing.gatewayEnabled &&
                  status?.entitled != true &&
                  !_busy,
              onCheckout: _checkout,
            ),
          const SizedBox(height: 12),
          BillingStatusCard(status: status, busy: _busy, onVerify: _poll),
          const SizedBox(height: 12),
          BillingHistoryList(
            projectId: widget.projectId,
            items: _history,
            repository: _repository,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const LocalizedUiText('Refresh'),
              ),
              TextButton(
                onPressed:
                    () => context.go('/projects/${widget.projectId}/overview'),
                child: Text(
                  uiText(
                    context,
                    'Back to project',
                    'திட்டத்திற்கு திரும்பவும்',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
