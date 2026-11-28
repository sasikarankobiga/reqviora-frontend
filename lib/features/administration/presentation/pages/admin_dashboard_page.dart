import 'package:flutter/material.dart';
import 'package:reqviora_frontend/l10n/language_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../projects/application/projects_providers.dart';
import '../../data/repositories/admin_repository.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  final _code = TextEditingController();
  final _search = TextEditingController();

  AdminSection _section = AdminSection.overview;
  AdminResult? _result;

  bool _busy = false;
  String? _error;
  int _page = 1;
  int _operation = 0;
  int _generation = authSession.generation;
  String _activeSearch = '';

  @override
  void initState() {
    super.initState();
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) {
      return;
    }

    _generation = authSession.generation;
    _operation++;

    _code.clear();
    _search.clear();

    setState(() {
      _result = null;
      _error = null;
      _busy = false;
      _page = 1;
      _activeSearch = '';
    });
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    _code.dispose();
    _search.dispose();
    super.dispose();
  }

  void _selectSection(AdminSection section) {
    if (_busy || section == _section) return;

    _code.clear();
    _search.clear();

    setState(() {
      _section = section;
      _result = null;
      _error = null;
      _page = 1;
      _activeSearch = '';
    });
  }

  Future<void> _load({int? targetPage}) async {
    if (_busy || isLocalDemo || !authSession.authenticated) {
      return;
    }

    final code = _code.text.trim();

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() {
        _error = 'Enter a valid six-digit authenticator code.';
      });
      return;
    }

    final section = _section;
    final requestedPage = targetPage ?? 1;
    final search = targetPage == null ? _search.text.trim() : _activeSearch;

    final operation = ++_operation;
    final generation = authSession.generation;

    _code.clear();

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    bool current() =>
        mounted &&
        operation == _operation &&
        generation == authSession.generation &&
        authSession.authenticated;

    try {
      final repository = AdminRepository(ref.read(apiClientProvider));

      final result = await repository.load(
        section,
        code,
        page: requestedPage,
        search: search,
      );

      if (!current()) return;

      setState(() {
        _result = result;
        _page = requestedPage;
        _activeSearch = search;
      });
    } on ApiException catch (error) {
      if (!current()) return;

      setState(() {
        _error = switch (error.statusCode) {
          400 => 'Invalid request. Check the entered values.',
          401 => 'Authentication or MFA verification failed.',
          403 => 'You are not authorized to access administration.',
          429 => 'Too many requests. Try again later.',
          0 => 'Cannot connect to the backend.',
          _ => 'Unable to load administration data.',
        };
      });
    } on FormatException {
      if (!current()) return;

      setState(() {
        _error = 'The server returned an incompatible response.';
      });
    } catch (_) {
      if (!current()) return;

      setState(() {
        _error = 'Unable to complete the request. Please retry.';
      });
    } finally {
      if (current()) {
        setState(() => _busy = false);
      }
    }
  }

  String _label(String value) {
    final separated = value.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    );

    if (separated.isEmpty) return value;

    return separated[0].toUpperCase() + separated.substring(1);
  }

  Widget _dataCard(Map<String, Object?> row) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final field in row.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedLabel(context, _label(field.key)),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    SelectableText(
                      field.value?.toString() ??
                          localizedLabel(context, 'Not available'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final section in AdminSection.values)
          ChoiceChip(
            key: ValueKey('admin-section-${section.name}'),
            label: Text(localizedLabel(context, section.label)),
            selected: _section == section,
            onSelected: _busy ? null : (_) => _selectSection(section),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLocalDemo || !authSession.authenticated) {
      return Scaffold(
        appBar: AppBar(title: const LocalizedUiText('Administration')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/projects'),
            child: const LocalizedUiText('Return to REQVIORA'),
          ),
        ),
      );
    }

    final result = _result;
    final total = result?.total ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const LocalizedUiText('Administration'),
        actions: [
          TextButton(
            onPressed: () => context.go('/account'),
            child: const LocalizedUiText('My account'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizedLabel(context, 'Operations dashboard'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const LocalizedUiText(
                  'Read-only administration. Access is verified '
                  'by the server for every request.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('admin-validation-health'),
                      onPressed:
                          () => context.go('/administration/validation-health'),
                      icon: const Icon(Icons.fact_check),
                      label: Text(
                        uiText(
                          context,
                          'Validation health',
                          'சரிபார்ப்பு நிலை',
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('admin-ai-queue'),
                      onPressed: () => context.go('/administration/ai-queue'),
                      icon: const Icon(Icons.memory),
                      label: Text(
                        uiText(
                          context,
                          'AI queue monitoring',
                          'AI வரிசை கண்காணிப்பு',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionSelector(),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          localizedLabel(context, _section.label),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        if (_section.searchable) ...[
                          TextField(
                            controller: _search,
                            enabled: !_busy,
                            maxLength: 120,
                            decoration: InputDecoration(
                              labelText: localizedLabel(context, 'Search'),
                              prefixIcon: const Icon(Icons.search),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          key: const ValueKey('admin-mfa-code'),
                          controller: _code,
                          enabled: !_busy,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            labelText: localizedLabel(
                              context,
                              'Authenticator code',
                            ),
                            helperText: localizedLabel(
                              context,
                              'Enter a current six-digit code.',
                            ),
                            prefixIcon: const Icon(Icons.verified_user),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const ValueKey('admin-load'),
                          onPressed: _busy ? null : () => _load(),
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            localizedLabel(
                              context,
                              _busy ? 'Loading...' : 'Verify and load',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      localizedLabel(context, _error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (result != null) ...[
                  if (result.healthStatus != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${localizedLabel(context, "System status")}: ${result.healthStatus}',
                        ),
                      ),
                    ),
                  if (result.rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        localizedLabel(context, 'No records found.'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final row in result.rows) _dataCard(row),
                  if (_section.paged)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _busy || _page <= 1
                                  ? null
                                  : () => _load(targetPage: _page - 1),
                          child: const LocalizedUiText('Previous'),
                        ),
                        Text(
                          '${localizedLabel(context, "Page")} $_page - $total ${localizedLabel(context, "records")}',
                        ),
                        OutlinedButton(
                          onPressed:
                              _busy || _page * 20 >= total
                                  ? null
                                  : () => _load(targetPage: _page + 1),
                          child: const LocalizedUiText('Next'),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
