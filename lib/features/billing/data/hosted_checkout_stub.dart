import '../domain/billing_models.dart';
import '../domain/hosted_checkout_port.dart';

class UnsupportedHostedCheckout implements HostedCheckoutPort {
  @override
  void submit(BillingCheckout checkout) {
    throw UnsupportedError('Hosted checkout requires Flutter Web');
  }
}

HostedCheckoutPort createHostedCheckout() => UnsupportedHostedCheckout();
