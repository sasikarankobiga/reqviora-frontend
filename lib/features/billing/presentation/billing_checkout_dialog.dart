import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../l10n/language_settings.dart';
import '../data/billing_repository.dart';
import '../domain/billing_models.dart';
import '../domain/hosted_checkout_port.dart';

class BillingCheckoutDialog extends StatefulWidget {
  const BillingCheckoutDialog({
    super.key,
    required this.projectId,
    required this.pricing,
    required this.repository,
    required this.hostedCheckout,
  });

  final String projectId;
  final ProjectPricing pricing;
  final BillingRepository repository;
  final HostedCheckoutPort hostedCheckout;

  @override
  State<BillingCheckoutDialog> createState() => _BillingCheckoutDialogState();
}

class _BillingCheckoutDialogState extends State<BillingCheckoutDialog> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'Sri Lanka');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _first,
      _last,
      _email,
      _phone,
      _address,
      _city,
      _country,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return uiText(context, 'Required field.', 'தேவையான புலம்.');
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final checkout = await widget.repository.checkout(
        projectId: widget.projectId,
        contact: CheckoutContact(
          firstName: _first.text,
          lastName: _last.text,
          email: _email.text,
          phone: _phone.text,
          address: _address.text,
          city: _city.text,
          country: _country.text,
        ),
      );
      if (!mounted) return;
      widget.hostedCheckout.submit(checkout);
      Navigator.pop(context, true);
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        _error =
            failure is ApiException && failure.statusCode == 403
                ? uiText(
                  context,
                  'Only the project owner can start checkout.',
                  'திட்ட உரிமையாளர் மட்டுமே கட்டணத்தை தொடங்க முடியும்.',
                )
                : uiText(
                  context,
                  'Checkout could not be started.',
                  'கட்டணத்தை தொடங்க முடியவில்லை.',
                );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String english,
    String tamil, {
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_busy,
      keyboardType: keyboard,
      validator: _required,
      decoration: InputDecoration(labelText: uiText(context, english, tamil)),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      uiText(context, 'Secure PayHere Checkout', 'பாதுகாப்பான PayHere கட்டணம்'),
    ),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.pricing.currency} ${widget.pricing.displayAmount}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                uiText(
                  context,
                  'The amount is supplied and verified by the server. Card details are entered only on PayHere.',
                  'தொகை சேவையகத்தால் வழங்கப்பட்டு சரிபார்க்கப்படுகிறது. அட்டை விவரங்கள் PayHere-ல் மட்டும் உள்ளிடப்படும்.',
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      constraints.maxWidth >= 520
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: _field(_first, 'First name', 'முதல் பெயர்'),
                      ),
                      SizedBox(
                        width: width,
                        child: _field(_last, 'Last name', 'கடைசி பெயர்'),
                      ),
                      SizedBox(
                        width: width,
                        child: _field(
                          _email,
                          'Email',
                          'மின்னஞ்சல்',
                          keyboard: TextInputType.emailAddress,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _field(
                          _phone,
                          'Phone',
                          'தொலைபேசி',
                          keyboard: TextInputType.phone,
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _field(_address, 'Address', 'முகவரி'),
                      ),
                      SizedBox(
                        width: width,
                        child: _field(_city, 'City', 'நகரம்'),
                      ),
                      SizedBox(
                        width: width,
                        child: _field(_country, 'Country', 'நாடு'),
                      ),
                    ],
                  );
                },
              ),
              if (_busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const LocalizedUiText('Cancel'),
      ),
      FilledButton.icon(
        key: const ValueKey('start-payhere-checkout'),
        onPressed: _busy ? null : _submit,
        icon: const Icon(Icons.open_in_new),
        label: Text(
          uiText(context, 'Continue to PayHere', 'PayHere-க்கு தொடரவும்'),
        ),
      ),
    ],
  );
}
