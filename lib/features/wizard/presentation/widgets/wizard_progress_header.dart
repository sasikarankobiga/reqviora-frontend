import 'package:flutter/material.dart';

import '../../domain/models/wizard_flow.dart';

class WizardProgressHeader extends StatelessWidget {
  const WizardProgressHeader({
    super.key,
    required this.flow,
    required this.currentStep,
  });

  final WizardFlow flow;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Step $currentStep of ${flow.totalSteps}',
          key: const Key('wizard-step-count'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          key: const Key('wizard-progress'),
          value: flow.completionProgress,
          minHeight: 8,
        ),
        const SizedBox(height: 8),
        Text(
          '${flow.completedSteps.length} of '
          '${flow.totalSteps} steps completed',
          key: const Key('wizard-completed-count'),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(flow.totalSteps, (index) {
            final step = index + 1;
            final complete = flow.isComplete(step);

            return Chip(
              key: Key('wizard-chip-$step'),
              avatar: Icon(
                complete
                    ? Icons.check_circle
                    : step == currentStep
                        ? Icons.radio_button_checked
                        : Icons.circle_outlined,
                size: 16,
              ),
              label: Text('$step. ${WizardFlow.nameOf(step)}'),
              backgroundColor: step == currentStep
                  ? theme.colorScheme.primaryContainer
                  : null,
            );
          }),
        ),
      ],
    );
  }
}
