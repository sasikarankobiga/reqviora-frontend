import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/language_settings.dart';

class ProjectBillingButton extends StatelessWidget {
  const ProjectBillingButton({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('open-project-billing'),
    onPressed: () => context.go('/projects/$projectId/billing'),
    icon: const Icon(Icons.payments_outlined),
    label: Text(
      uiText(context, 'Billing & Entitlement', 'கட்டணம் மற்றும் உரிமை'),
    ),
  );
}
