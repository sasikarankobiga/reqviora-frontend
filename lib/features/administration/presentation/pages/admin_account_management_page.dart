import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../data/repositories/admin_account_repository.dart';

/// Integration-ready component for the Administrator-policy API.
/// Register this page only after confirming the final server MFA policy.
class AdminAccountManagementPage extends StatefulWidget {
  const AdminAccountManagementPage({
    super.key,
    required this.repository,
    required this.actorId,
    required this.availableRoles,
    this.integrationEnabled = false,
  });

  final AdminAccountRepository repository;
  final String actorId;
  final List<String> availableRoles;
  final bool integrationEnabled;

  @override
  State<AdminAccountManagementPage> createState() =>
      _AdminAccountManagementPageState();
}

class _AdminAccountManagementPageState
    extends State<AdminAccountManagementPage> {
  final _search = TextEditingController();

  AdminAccountStatus _status = AdminAccountStatus.all;
  AdminAccountPage? _result;
  bool _busy = false;
  String? _error;
  String? _notice;
  String _activeSearch = '';
  int _operation = 0;
  int _generation = authSession.generation;

  bool get _allowed =>
      widget.integrationEnabled &&
      authSession.authenticated &&
      AdminAccountRepository.validId(widget.actorId);

  String tr(String en, String ta) => uiText(context, en, ta);

  @override
  void initState() {
    super.initState();
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) return;

    _generation = authSession.generation;
    _operation++;
    _search.clear();

    setState(() {
      _result = null;
      _busy = false;
      _error = null;
      _notice = null;
      _activeSearch = '';
      _status = AdminAccountStatus.all;
    });
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    _search.dispose();
    super.dispose();
  }

  bool _current(int operation, int generation) =>
      mounted &&
      _allowed &&
      operation == _operation &&
      generation == authSession.generation;

  String _describeError(Object error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => tr('Authentication required.', 'அங்கீகாரம் தேவை.'),
        403 => tr('Permission denied.', 'அனுமதி மறுக்கப்பட்டது.'),
        404 => tr('Account not found.', 'கணக்கு கிடைக்கவில்லை.'),
        409 => tr(
          'Conflict. Refresh and retry.',
          'முரண்பாடு. புதுப்பித்து முயற்சிக்கவும்.',
        ),
        429 => tr('Too many requests.', 'அதிகமான கோரிக்கைகள்.'),
        0 => tr('Server unavailable.', 'சேவையகம் கிடைக்கவில்லை.'),
        _ => tr('Request failed.', 'கோரிக்கை தோல்வியடைந்தது.'),
      };
    }

    return tr(
      'Unable to process account data.',
      'கணக்குத் தரவைச் செயலாக்க முடியவில்லை.',
    );
  }

  Future<void> _load({int page = 1, bool reuseSearch = false}) async {
    if (!_allowed || _busy) return;

    final operation = ++_operation;
    final generation = authSession.generation;
    final search = reuseSearch ? _activeSearch : _search.text.trim();

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await widget.repository.getUsers(
        page: page,
        search: search,
        status: _status,
      );

      if (!_current(operation, generation)) return;

      setState(() {
        _result = result;
        _activeSearch = search;
      });
    } catch (error) {
      if (!_current(operation, generation)) return;
      setState(() => _error = _describeError(error));
    } finally {
      if (_current(operation, generation)) {
        setState(() => _busy = false);
      }
    }
  }

  bool _canModify(AdminAccount account) =>
      _allowed &&
      !_busy &&
      _result != null &&
      account.id.toLowerCase() != widget.actorId.toLowerCase();

  Future<void> _mutate(
    AdminAccount account,
    Future<AdminAccount> Function() action,
  ) async {
    if (!_canModify(account)) return;

    final operation = ++_operation;
    final generation = authSession.generation;

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      await action();

      if (!_current(operation, generation)) return;

      setState(() {
        _busy = false;
        _notice = tr('Account updated.', 'கணக்கு புதுப்பிக்கப்பட்டது.');
      });

      await _load(reuseSearch: true);
    } catch (error) {
      if (!_current(operation, generation)) return;

      setState(() {
        _error = _describeError(error);
        _result = null;
      });
    } finally {
      if (_current(operation, generation)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _changeStatus(AdminAccount account) async {
    if (!_canModify(account)) return;

    final generation = authSession.generation;
    final disabled = !account.isDisabled;
    final formKey = GlobalKey<FormState>();
    var reasonInput = '';

    final reason = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(
              disabled
                  ? tr('Disable account?', 'கணக்கை முடக்கவா?')
                  : tr('Enable account?', 'கணக்கை இயக்கவா?'),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(account.email),
                  if (disabled)
                    TextFormField(
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: tr('Reason', 'காரணம்'),
                      ),
                      onChanged: (value) => reasonInput = value,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return tr('Enter a reason.', 'காரணத்தை உள்ளிடவும்.');
                        }
                        return null;
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr('Cancel', 'ரத்து செய்')),
              ),
              FilledButton(
                onPressed: () {
                  if (generation != authSession.generation) {
                    Navigator.pop(dialogContext);
                    return;
                  }

                  if (formKey.currentState?.validate() != true) return;

                  Navigator.pop(dialogContext, reasonInput.trim());
                },
                child: Text(tr('Confirm', 'உறுதிப்படுத்து')),
              ),
            ],
          ),
    );

    if (!mounted || reason == null || generation != authSession.generation) {
      return;
    }

    await _mutate(
      account,
      () => widget.repository.setStatus(
        userId: account.id,
        actorId: widget.actorId,
        disabled: disabled,
        reason: reason,
      ),
    );
  }

  Future<void> _changeRole(AdminAccount account) async {
    if (!_canModify(account)) return;

    final generation = authSession.generation;

    final roles =
        widget.availableRoles
            .map((role) => role.trim())
            .where((role) => role.isNotEmpty && role.length <= 100)
            .where((role) => role.toLowerCase() != account.role.toLowerCase())
            .toSet()
            .toList();

    if (roles.isEmpty) return;

    String selected = roles.first;

    final role = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, update) => AlertDialog(
                  title: Text(tr('Change role', 'பொறுப்பை மாற்றவும்')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(account.email),
                      DropdownButtonFormField<String>(
                        initialValue: selected,
                        isExpanded: true,
                        items: [
                          for (final item in roles)
                            DropdownMenuItem(value: item, child: Text(item)),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            update(() => selected = value);
                          }
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(tr('Cancel', 'ரத்து செய்')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, selected),
                      child: Text(tr('Confirm', 'உறுதிப்படுத்து')),
                    ),
                  ],
                ),
          ),
    );

    if (!mounted || role == null || generation != authSession.generation) {
      return;
    }

    await _mutate(
      account,
      () => widget.repository.setRole(
        userId: account.id,
        actorId: widget.actorId,
        role: role,
      ),
    );
  }

  Widget _accountCard(AdminAccount account) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SelectableText(account.email),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(account.role)),
                Chip(
                  label: Text(
                    account.isDisabled
                        ? tr('Disabled', 'முடக்கப்பட்டது')
                        : tr('Enabled', 'இயக்கத்தில் உள்ளது'),
                  ),
                ),
                Chip(
                  label: Text(
                    account.emailVerified
                        ? tr('Email verified', 'மின்னஞ்சல் உறுதிசெய்யப்பட்டது')
                        : tr(
                          'Email unverified',
                          'மின்னஞ்சல் உறுதிசெய்யப்படவில்லை',
                        ),
                  ),
                ),
                Chip(
                  label: Text(
                    account.mfaEnabled
                        ? tr('MFA enabled', 'MFA இயக்கப்பட்டுள்ளது')
                        : tr('MFA disabled', 'MFA இயக்கப்படவில்லை'),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed:
                      _canModify(account) ? () => _changeStatus(account) : null,
                  child: Text(
                    account.isDisabled
                        ? tr('Enable', 'இயக்கு')
                        : tr('Disable', 'முடக்கு'),
                  ),
                ),
                OutlinedButton(
                  onPressed:
                      _canModify(account) && widget.availableRoles.isNotEmpty
                          ? () => _changeRole(account)
                          : null,
                  child: Text(tr('Change role', 'பொறுப்பை மாற்று')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Account Management', 'கணக்கு மேலாண்மை'))),
      body:
          !_allowed
              ? Center(
                child: Text(
                  tr(
                    'Admin integration is unavailable.',
                    'நிர்வாக இணைப்பு கிடைக்கவில்லை.',
                  ),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _search,
                          enabled: !_busy,
                          maxLength: 200,
                          decoration: InputDecoration(
                            labelText: tr('Search users', 'பயனர்களைத் தேடவும்'),
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                        DropdownButtonFormField<AdminAccountStatus>(
                          initialValue: _status,
                          items: [
                            for (final value in AdminAccountStatus.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(switch (value) {
                                  AdminAccountStatus.all => tr(
                                    'All',
                                    'அனைத்தும்',
                                  ),
                                  AdminAccountStatus.enabled => tr(
                                    'Enabled',
                                    'இயக்கத்தில் உள்ளது',
                                  ),
                                  AdminAccountStatus.disabled => tr(
                                    'Disabled',
                                    'முடக்கப்பட்டது',
                                  ),
                                }),
                              ),
                          ],
                          onChanged:
                              _busy
                                  ? null
                                  : (value) {
                                    if (value != null) {
                                      setState(() {
                                        _status = value;
                                        _result = null;
                                      });
                                    }
                                  },
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const ValueKey('admin-account-load'),
                          onPressed: _busy ? null : () => _load(),
                          child: Text(
                            tr('Load accounts', 'கணக்குகளைப் பெறவும்'),
                          ),
                        ),
                        if (_busy) const LinearProgressIndicator(),
                        if (_error != null)
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        if (_notice != null) Text(_notice!),
                        if (result != null) ...[
                          if (result.items.isEmpty)
                            Text(
                              tr(
                                'No accounts found.',
                                'கணக்குகள் கிடைக்கவில்லை.',
                              ),
                            ),
                          for (final account in result.items)
                            _accountCard(account),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton(
                                onPressed:
                                    _busy || result.page <= 1
                                        ? null
                                        : () => _load(
                                          page: result.page - 1,
                                          reuseSearch: true,
                                        ),
                                child: Text(tr('Previous', 'முந்தையது')),
                              ),
                              Text('${result.page} / ${result.total}'),
                              OutlinedButton(
                                onPressed:
                                    _busy ||
                                            result.page * result.pageSize >=
                                                result.total
                                        ? null
                                        : () => _load(
                                          page: result.page + 1,
                                          reuseSearch: true,
                                        ),
                                child: Text(tr('Next', 'அடுத்தது')),
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
