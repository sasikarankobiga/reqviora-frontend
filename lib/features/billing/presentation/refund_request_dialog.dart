import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../l10n/language_settings.dart';
import '../data/billing_repository.dart';
import '../domain/billing_models.dart';

class RefundRequestDialog extends StatefulWidget {
  const RefundRequestDialog({
    super.key,
    required this.projectId,
    required this.payment,
    required this.repository,
  });
  final String projectId;
  final PaymentDetails payment;
  final BillingRepository repository;

  @override
  State<RefundRequestDialog> createState() => _RefundRequestDialogState();
}

class _RefundRequestDialogState extends State<RefundRequestDialog> {
  String _reason = 'service_issue';
  bool _busy = false;
  String? _message;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await widget.repository.requestRefund(
        projectId: widget.projectId,
        paymentId: widget.payment.id,
        reason: _reason,
      );
      if (mounted) {
        setState(
          () =>
              _message =
                  '${uiText(context, 'Refund status', 'பணத்தைத் திருப்புதல் நிலை')}: ${result.status}',
        );
      }
    } catch (failure) {
      if (!mounted) return;
      setState(
        () =>
            _message =
                failure is ApiException && failure.statusCode == 503
                    ? uiText(
                      context,
                      'Refund requests are available only in the configured sandbox environment.',
                      'பணத்தைத் திருப்புதல் கோரிக்கைகள் அமைக்கப்பட்ட சோதனை சூழலில் மட்டும் கிடைக்கும்.',
                    )
                    : uiText(
                      context,
                      'Refund request could not be submitted.',
                      'பணத்தைத் திருப்புதல் கோரிக்கையை சமர்ப்பிக்க முடியவில்லை.',
                    ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      uiText(context, 'Request Refund', 'பணத்தைத் திருப்பக் கோரவும்'),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _reason,
          decoration: InputDecoration(
            labelText: uiText(context, 'Reason', 'காரணம்'),
          ),
          items: [
            DropdownMenuItem(
              value: 'duplicate_payment',
              child: Text(uiText(context, 'Duplicate payment', 'நகல் கட்டணம்')),
            ),
            DropdownMenuItem(
              value: 'service_issue',
              child: Text(uiText(context, 'Service issue', 'சேவை சிக்கல்')),
            ),
            DropdownMenuItem(
              value: 'other',
              child: Text(uiText(context, 'Other', 'மற்றவை')),
            ),
          ],
          onChanged:
              _busy
                  ? null
                  : (value) => setState(() => _reason = value ?? _reason),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(liveRegion: true, child: Text(_message!)),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const LocalizedUiText('Close'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(uiText(context, 'Submit', 'சமர்ப்பிக்கவும்')),
      ),
    ],
  );
}
