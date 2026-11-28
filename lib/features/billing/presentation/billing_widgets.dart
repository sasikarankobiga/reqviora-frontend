import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/language_settings.dart';
import '../data/billing_repository.dart';
import '../domain/billing_models.dart';
import 'refund_request_dialog.dart';

String billingStatusLabel(
  BuildContext context,
  PaymentStatus status,
) => switch (status) {
  PaymentStatus.pending => uiText(context, 'Pending', 'நிலுவையில்'),
  PaymentStatus.processing => uiText(
    context,
    'Processing',
    'செயலாக்கப்படுகிறது',
  ),
  PaymentStatus.succeeded => uiText(context, 'Successful', 'வெற்றிகரமானது'),
  PaymentStatus.failed => uiText(context, 'Failed', 'தோல்வியடைந்தது'),
  PaymentStatus.cancelled => uiText(
    context,
    'Cancelled',
    'ரத்து செய்யப்பட்டது',
  ),
  PaymentStatus.refunded => uiText(context, 'Refunded', 'பணம் திருப்பப்பட்டது'),
  PaymentStatus.disputed => uiText(context, 'Disputed', 'சர்ச்சைக்குரியது'),
};

class BillingPricingCard extends StatelessWidget {
  const BillingPricingCard({
    super.key,
    required this.pricing,
    required this.checkoutEnabled,
    required this.onCheckout,
  });

  final ProjectPricing pricing;
  final bool checkoutEnabled;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${pricing.currency} ${pricing.displayAmount}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            pricing.gatewayEnabled
                ? uiText(context, 'PayHere available', 'PayHere கிடைக்கிறது')
                : uiText(
                  context,
                  'Checkout unavailable',
                  'கட்டணம் கிடைக்கவில்லை',
                ),
          ),
          FilledButton.icon(
            onPressed: checkoutEnabled ? onCheckout : null,
            icon: const Icon(Icons.open_in_new),
            label: Text(
              uiText(context, 'Open Checkout', 'கட்டணத்தைத் திறக்கவும்'),
            ),
          ),
        ],
      ),
    ),
  );
}

class BillingStatusCard extends StatelessWidget {
  const BillingStatusCard({
    super.key,
    required this.status,
    required this.busy,
    required this.onVerify,
  });

  final PaymentDetails? status;
  final bool busy;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiText(context, 'Verified Status', 'சரிபார்க்கப்பட்ட நிலை'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (status == null)
            Text(
              uiText(
                context,
                'No payment has been verified for this project.',
                'இந்த திட்டத்திற்கு கட்டணம் சரிபார்க்கப்படவில்லை.',
              ),
            )
          else ...[
            Text(
              '${billingStatusLabel(context, status!.status)} · '
              '${status!.currency} '
              '${(status!.amountMinor / 100).toStringAsFixed(2)}',
            ),
            Text(
              status!.entitled
                  ? uiText(
                    context,
                    'Entitlement active',
                    'உரிமை செயலில் உள்ளது',
                  )
                  : uiText(context, 'Entitlement inactive', 'உரிமை செயலற்றது'),
            ),
          ],
          OutlinedButton.icon(
            onPressed: busy ? null : onVerify,
            icon: const Icon(Icons.verified_outlined),
            label: Text(
              uiText(
                context,
                'Verify with server',
                'சேவையகத்துடன் சரிபார்க்கவும்',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class BillingHistoryList extends StatelessWidget {
  const BillingHistoryList({
    super.key,
    required this.projectId,
    required this.items,
    required this.repository,
  });

  final String projectId;
  final List<PaymentDetails> items;
  final BillingRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        uiText(context, 'Payment History', 'கட்டண வரலாறு'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (items.isEmpty)
        Text(uiText(context, 'No payments found.', 'கட்டணங்கள் இல்லை.')),
      for (final payment in items)
        Card(
          child: ListTile(
            title: Text(payment.orderId),
            subtitle: Text(
              '${billingStatusLabel(context, payment.status)} · '
              '${payment.createdAt.toLocal()}',
            ),
            trailing:
                kDebugMode && payment.status == PaymentStatus.succeeded
                    ? TextButton(
                      onPressed:
                          () => showDialog<void>(
                            context: context,
                            builder:
                                (_) => RefundRequestDialog(
                                  projectId: projectId,
                                  payment: payment,
                                  repository: repository,
                                ),
                          ),
                      child: Text(uiText(context, 'Refund', 'பணம் திரும்ப')),
                    )
                    : null,
          ),
        ),
    ],
  );
}
