import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../domain/models/wizard_flow.dart';
import '../widgets/wizard_progress_header.dart';
import '../widgets/builder_step2_panel.dart';
import '../widgets/builder_step3_panel.dart';

class BuilderWorkflowPage extends StatefulWidget {
  const BuilderWorkflowPage({
    super.key,
    required this.routeData,
  });

  final WizardStepRouteData routeData;

  @override
  State<BuilderWorkflowPage> createState() => _BuilderWorkflowPageState();
}

class _BuilderWorkflowPageState extends State<BuilderWorkflowPage> {
  @override
  void initState() {
    super.initState();
    widget.routeData.flow.visitStep(widget.routeData.step);
  }

  void _next() {
    final current = widget.routeData.step;
    final flow = widget.routeData.flow;

    if (current >= flow.totalSteps) {
      return;
    }

    Navigator.pushNamed(
      context,
      RoutePaths.builderWorkflow,
      arguments: WizardStepRouteData(
        flow: flow,
        step: current + 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.routeData.step;
    final flow = widget.routeData.flow;
    final isLast = step == flow.totalSteps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('REQVIORA Builder'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              WizardProgressHeader(
                flow: flow,
                currentStep: step,
              ),
              const SizedBox(height: 28),
              Text(
                WizardFlow.nameOf(step),
                key: const Key('wizard-current-title'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Project: ${flow.draft.name}',
                key: const Key('wizard-project-name'),
              ),
              const SizedBox(height: 20),
              if (step == 2)
                BuilderStep2Panel(
                  flow: flow,
                  onNext: _next,
                )
              else if (step == 3)
                BuilderStep3Panel(
                  flow: flow,
                  onNext: _next,
                )
              else
                const Text(
                  'This is a workflow navigation placeholder. '
                  'Step-specific fields, validation and saving '
                  'will be implemented separately.',
                ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    key: const Key('wizard-back'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  if (!isLast && step != 2 && step != 3)
                    FilledButton.icon(
                      key: const Key('wizard-next'),
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next (Navigation Preview)'),
                    ),
                  if (isLast)
                    const Text(
                      'Review and approval integration pending.',
                      key: Key('wizard-final-pending'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
