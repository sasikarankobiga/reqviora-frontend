// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import '../domain/billing_models.dart';
import '../domain/hosted_checkout_port.dart';

class BrowserHostedCheckout implements HostedCheckoutPort {
  @override
  void submit(BillingCheckout checkout) {
    final form =
        html.FormElement()
          ..method = 'POST'
          ..action = checkout.actionUrl.toString()
          ..target = '_self';
    for (final entry in checkout.fields.entries) {
      form.append(
        html.InputElement(type: 'hidden')
          ..name = entry.key
          ..value = entry.value,
      );
    }
    html.document.body?.append(form);
    try {
      form.submit();
    } finally {
      form.remove();
    }
  }
}

HostedCheckoutPort createHostedCheckout() => BrowserHostedCheckout();
