import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../../projects/application/projects_providers.dart';
import '../../data/repositories/admin_billing_repository.dart';
import '../../domain/admin_billing_models.dart';

class AdminBillingPage extends ConsumerStatefulWidget {
  const AdminBillingPage({super.key});
  @override
  ConsumerState<AdminBillingPage> createState() => _AdminBillingPageState();
}

class _AdminBillingPageState extends ConsumerState<AdminBillingPage> {
  final _code = TextEditingController();
  final _project = TextEditingController();
  late final AdminBillingRepository _repository;
  AdminPaymentStatus _status = AdminPaymentStatus.all;
  AdminBillingCurrency _currency = AdminBillingCurrency.all;
  AdminBillingSummary? _summary;
  AdminPaymentPage? _payments;
  AdminRefundPage? _refunds;
  bool _refundMode = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  int _operation = 0;
  int _generation = authSession.generation;

  @override
  void initState() {
    super.initState();
    _repository = AdminBillingRepository(ref.read(apiClientProvider));
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_generation == authSession.generation) return;
    _generation = authSession.generation;
    _operation++;
    _code.clear();
    _project.clear();
    if (mounted) {
      setState(() {
        _summary = null;
        _payments = null;
        _refunds = null;
        _busy = false;
        _error = null;
        _notice = null;
      });
    }
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _code.dispose();
    _project.dispose();
    super.dispose();
  }

  String _t(String en, String ta) => uiText(context, en, ta);
  String _date(DateTime value) => value.toLocal().toString();
  bool _current(int operation, int generation) =>
      mounted &&
      operation == _operation &&
      generation == authSession.generation &&
      authSession.authenticated;

  String _apiError(ApiException error) => switch (error.statusCode) {
    401 => _t(
      'Authentication or a fresh administrator MFA code is required.',
      'உள்நுழைவும் புதிய நிர்வாகி MFA குறியீடும் தேவை.',
    ),
    403 => _t(
      'Billing administration is not authorized.',
      'பில்லிங் நிர்வாகம் அனுமதிக்கப்படவில்லை.',
    ),
    404 => _t(
      'The payment or refund was not found.',
      'கட்டணம் அல்லது பணத்திருப்பல் கிடைக்கவில்லை.',
    ),
    409 => _t(
      'The refund was already reviewed or is no longer eligible.',
      'பணத்திருப்பல் ஏற்கனவே மதிப்பாய்வு செய்யப்பட்டது அல்லது தகுதியற்றது.',
    ),
    503 => _t(
      'Sandbox billing administration is unavailable on this backend.',
      'இந்த பின்தளத்தில் sandbox பில்லிங் நிர்வாகம் கிடைக்கவில்லை.',
    ),
    _ => _t(
      'Unable to complete the billing request.',
      'பில்லிங் கோரிக்கையை முடிக்க முடியவில்லை.',
    ),
  };

  Future<void> _load([int page = 1]) async {
    if (_busy || !authSession.authenticated || isLocalDemo) return;
    final code = _code.text.trim();
    _code.clear();
    final operation = ++_operation;
    final generation = authSession.generation;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_refundMode) {
        final refunds = await _repository.refunds(code: code, page: page);
        if (!_current(operation, generation)) return;
        setState(() => _refunds = refunds);
      } else {
        final project = _project.text.trim();
        final values = await Future.wait<Object>([
          _repository.summary(code),
          _repository.payments(
            code: code,
            page: page,
            projectId: project.isEmpty ? null : project,
            status: _status,
            currency: _currency,
          ),
        ]);
        if (!_current(operation, generation)) return;
        setState(() {
          _summary = values[0] as AdminBillingSummary;
          _payments = values[1] as AdminPaymentPage;
        });
      }
    } on ArgumentError {
      if (_current(operation, generation)) {
        setState(
          () =>
              _error = _t(
                'Enter a valid project ID and current six-digit MFA code.',
                'சரியான திட்ட அடையாளத்தையும் தற்போதைய ஆறு இலக்க MFA குறியீட்டையும் உள்ளிடவும்.',
              ),
        );
      }
    } on ApiException catch (error) {
      if (_current(operation, generation)) {
        setState(() => _error = _apiError(error));
      }
    } on FormatException {
      if (_current(operation, generation)) {
        setState(
          () =>
              _error = _t(
                'The server returned incompatible billing data.',
                'பின்தளம் பொருந்தாத பில்லிங் தரவை வழங்கியது.',
              ),
        );
      }
    } finally {
      if (_current(operation, generation)) setState(() => _busy = false);
    }
  }

  Future<String?> _requestCode(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: TextField(
              key: const ValueKey('billing-dialog-code'),
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: _t('Authenticator code', 'அங்கீகார குறியீடு'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_t('Cancel', 'ரத்து செய்')),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: Text(_t('Confirm', 'உறுதிப்படுத்து')),
              ),
            ],
          ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _details(AdminPaymentItem item) async {
    final code = await _requestCode(
      _t('Verify payment access', 'கட்டண அணுகலை உறுதிப்படுத்து'),
    );
    if (code == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final details = await _repository.paymentDetails(item.paymentId, code);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(_t('Payment details', 'கட்டண விவரங்கள்')),
              content: SingleChildScrollView(child: _paymentMetadata(details)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(_t('Close', 'மூடு')),
                ),
              ],
            ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiError(error));
    } on ArgumentError {
      if (mounted) {
        setState(
          () =>
              _error = _t(
                'Enter a current six-digit MFA code.',
                'தற்போதைய ஆறு இலக்க MFA குறியீட்டை உள்ளிடவும்.',
              ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(AdminRefundItem item, String decision) async {
    final code = await _requestCode(
      decision == 'reviewed'
          ? _t(
            'Record refund review?',
            'பணத்திருப்பல் மதிப்பாய்வைப் பதிவு செய்யவா?',
          )
          : _t(
            'Reject refund request?',
            'பணத்திருப்பல் கோரிக்கையை நிராகரிக்கவா?',
          ),
    );
    if (code == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await _repository.reviewRefund(
        paymentId: item.paymentId,
        code: code,
        decision: decision,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _notice =
            '${_t('Refund review recorded', 'பணத்திருப்பல் மதிப்பாய்வு பதிவு செய்யப்பட்டது')}: ${result.status}. '
            '${_t('No financial transfer was initiated.', 'பணப் பரிமாற்றம் தொடங்கப்படவில்லை.')}';
      });
      _code.text = code;
      await _load(_refunds?.page ?? 1);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiError(error));
    } on StateError {
      if (mounted) {
        setState(
          () =>
              _error = _t(
                'This refund review is already in progress.',
                'இந்த பணத்திருப்பல் மதிப்பாய்வு ஏற்கனவே நடைபெறுகிறது.',
              ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _paymentMetadata(AdminPaymentItem item) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _line(_t('Payment ID', 'கட்டண அடையாளம்'), item.paymentId),
      _line(_t('Order reference', 'ஆர்டர் குறிப்பு'), item.orderReference),
      _line(_t('Project ID', 'திட்ட அடையாளம்'), item.projectId),
      _line(_t('Payer ID', 'செலுத்துபவர் அடையாளம்'), item.payerId),
      _line(
        _t('Amount', 'தொகை'),
        '${item.amount.toStringAsFixed(2)} ${item.currency}',
      ),
      _line(_t('Status', 'நிலை'), item.status),
      _line(_t('Created', 'உருவாக்கப்பட்டது'), _date(item.createdAt)),
      _line(_t('Updated', 'புதுப்பிக்கப்பட்டது'), _date(item.updatedAt)),
    ],
  );
  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SelectableText('$label: $value'),
  );

  @override
  Widget build(BuildContext context) {
    if (isLocalDemo || !authSession.authenticated) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_t('Billing administration', 'பில்லிங் நிர்வாகம்')),
        ),
        body: Center(
          child: Text(
            _t(
              'Authenticated administrator access is required.',
              'உள்நுழைந்த நிர்வாகி அணுகல் தேவை.',
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('Sandbox billing administration', 'Sandbox பில்லிங் நிர்வாகம்'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _t(
              'Development sandbox only. Refund reviews record workflow state and never transfer money.',
              'Development sandbox மட்டும். பணத்திருப்பல் மதிப்பாய்வுகள் பணிநிலையை மட்டும் பதிவு செய்கின்றன; பணம் பரிமாறாது.',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(_t('Payments', 'கட்டணங்கள்')),
                icon: const Icon(Icons.payments),
              ),
              ButtonSegment(
                value: true,
                label: Text(
                  _t('Refund reviews', 'பணத்திருப்பல் மதிப்பாய்வுகள்'),
                ),
                icon: const Icon(Icons.undo),
              ),
            ],
            selected: {_refundMode},
            onSelectionChanged:
                _busy
                    ? null
                    : (value) => setState(() {
                      _refundMode = value.single;
                      _error = null;
                      _notice = null;
                    }),
          ),
          const SizedBox(height: 16),
          _filters(),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_notice != null)
            Semantics(liveRegion: true, child: Text(_notice!)),
          if (!_refundMode) ...[
            _summaryCards(),
            _paymentDirectory(),
          ] else
            _refundDirectory(),
        ],
      ),
    );
  }

  Widget _filters() => Column(
    children: [
      if (!_refundMode)
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                key: const ValueKey('billing-project-filter'),
                controller: _project,
                decoration: InputDecoration(
                  labelText: _t(
                    'Project ID (optional)',
                    'திட்ட அடையாளம் (விருப்பம்)',
                  ),
                ),
              ),
            ),
            DropdownButton<AdminPaymentStatus>(
              value: _status,
              onChanged:
                  _busy ? null : (value) => setState(() => _status = value!),
              items:
                  AdminPaymentStatus.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
            ),
            DropdownButton<AdminBillingCurrency>(
              value: _currency,
              onChanged:
                  _busy ? null : (value) => setState(() => _currency = value!),
              items:
                  AdminBillingCurrency.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name.toUpperCase()),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      TextField(
        key: const ValueKey('admin-billing-code'),
        controller: _code,
        enabled: !_busy,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: InputDecoration(
          labelText: _t(
            'Fresh administrator MFA code',
            'புதிய நிர்வாகி MFA குறியீடு',
          ),
        ),
      ),
      FilledButton.icon(
        key: const ValueKey('admin-billing-load'),
        onPressed: _busy ? null : () => _load(),
        icon: const Icon(Icons.refresh),
        label: Text(_t('Verify and load', 'உறுதிப்படுத்தி ஏற்று')),
      ),
    ],
  );

  Widget _summaryCards() {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          summary.sandbox
              ? _t('Sandbox metrics', 'Sandbox அளவீடுகள்')
              : _t('Billing metrics', 'பில்லிங் அளவீடுகள்'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final item in summary.currencies)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  Text(
                    item.currency,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${_t('Total', 'மொத்தம்')}: ${item.totalOrders}'),
                  Text(
                    '${_t('Successful', 'வெற்றி')}: ${item.successfulOrders}',
                  ),
                  Text('${_t('Pending', 'நிலுவை')}: ${item.pendingOrders}'),
                  Text('${_t('Failed', 'தோல்வி')}: ${item.failedOrders}'),
                  Text('${_t('Cancelled', 'ரத்து')}: ${item.cancelledOrders}'),
                  Text(
                    '${_t('Chargebacks', 'திரும்பப்பெறல்கள்')}: ${item.chargebackOrders}',
                  ),
                  Text(
                    '${_t('Successful amount', 'வெற்றி தொகை')}: ${item.successfulOrderAmount.toStringAsFixed(2)} ${item.currency}',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _paymentDirectory() {
    final page = _payments;
    if (page == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_t('Transactions', 'பரிவர்த்தனைகள்')}: ${page.total}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (page.items.isEmpty)
          Text(
            _t('No matching transactions.', 'பொருந்தும் பரிவர்த்தனைகள் இல்லை.'),
          ),
        for (final item in page.items)
          Card(
            child: ListTile(
              title: Text(
                '${item.amount.toStringAsFixed(2)} ${item.currency} · ${item.status}',
              ),
              subtitle: Text(
                '${item.orderReference}\n${_t('Project', 'திட்டம்')}: ${item.projectId}',
              ),
              isThreeLine: true,
              onTap: _busy ? null : () => _details(item),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        _pager(page.page, page.pageSize, page.total),
      ],
    );
  }

  Widget _refundDirectory() {
    final page = _refunds;
    if (page == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_t('Refund requests', 'பணத்திருப்பல் கோரிக்கைகள்')}: ${page.total}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (page.items.isEmpty)
          Text(_t('No refund requests.', 'பணத்திருப்பல் கோரிக்கைகள் இல்லை.')),
        for (final item in page.items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(item.paymentId),
                  Text('${_t('Reason', 'காரணம்')}: ${item.reason}'),
                  Text('${_t('Status', 'நிலை')}: ${item.status}'),
                  Text('${_t('Sandbox', 'Sandbox')}: ${item.sandbox}'),
                  Text(
                    '${_t('Refund executed', 'பணத்திருப்பல் செயல்படுத்தப்பட்டது')}: ${item.refundExecuted}',
                  ),
                  if (item.status == 'requested')
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _busy ? null : () => _review(item, 'rejected'),
                          child: Text(_t('Reject', 'நிராகரி')),
                        ),
                        FilledButton(
                          onPressed:
                              _busy ? null : () => _review(item, 'reviewed'),
                          child: Text(
                            _t('Record reviewed', 'மதிப்பாய்வைப் பதிவு செய்'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        _pager(page.page, page.pageSize, page.total),
      ],
    );
  }

  Widget _pager(int page, int size, int total) => Wrap(
    spacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      OutlinedButton(
        onPressed: _busy || page <= 1 ? null : () => _load(page - 1),
        child: Text(_t('Previous', 'முந்தையது')),
      ),
      Text('${_t('Page', 'பக்கம்')} $page'),
      OutlinedButton(
        onPressed: _busy || page * size >= total ? null : () => _load(page + 1),
        child: Text(_t('Next', 'அடுத்தது')),
      ),
    ],
  );
}
