import 'billing_models.dart';

abstract interface class HostedCheckoutPort {
  void submit(BillingCheckout checkout);
}
