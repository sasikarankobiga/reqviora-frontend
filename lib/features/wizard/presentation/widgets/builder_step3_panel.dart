import 'package:flutter/material.dart';
import '../../domain/models/wizard_flow.dart';

class BuilderStep3Panel extends StatefulWidget {
  const BuilderStep3Panel({
    super.key,
    required this.flow,
    required this.onNext,
  });

  final WizardFlow flow;
  final VoidCallback onNext;

  @override
  State<BuilderStep3Panel> createState() => _BuilderStep3PanelState();
}

class _BuilderStep3PanelState extends State<BuilderStep3Panel> {
  final _actionController = TextEditingController();

  String? _sourceScreen;
  String? _destinationScreen;

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _selectStart(String? screen) {
    if (screen == null) return;

    widget.flow.navigation.setStartScreen(screen);

    setState(() {
      widget.flow.completedSteps.remove(3);
    });
  }

  void _addRoute() {
    final source = _sourceScreen;
    final destination = _destinationScreen;

    if (source == null || destination == null) {
      _message('Select source and destination screens');
      return;
    }

    try {
      widget.flow.navigation.addRoute(
        source: source,
        destination: destination,
        action: _actionController.text,
      );

      setState(() {
        _actionController.clear();
        widget.flow.completedSteps.remove(3);
      });

      _message('Navigation route added');
    } on ArgumentError catch (error) {
      _message(error.message?.toString() ?? 'Invalid route');
    }
  }

  void _removeRoute(int index) {
    final route = widget.flow.navigation.routes[index];

    setState(() {
      widget.flow.navigation.removeRoute(route);
      widget.flow.completedSteps.remove(3);
    });
  }

  void _next() {
    if (!widget.flow.navigation.isReady) {
      _message('Select a start screen and add a route');
      return;
    }

    widget.flow.completeStep(3);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final screens = widget.flow.featureScreens.screens;
    final navigation = widget.flow.navigation;
    final routes = navigation.routes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Navigation Setup',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose the first screen and define screen navigation.',
        ),
        const SizedBox(height: 20),
        DropdownButton<String>(
          key: const Key('step3-start-screen'),
          isExpanded: true,
          hint: const Text('Select Start Screen'),
          value: navigation.startScreen,
          items: [
            for (final screen in screens)
              DropdownMenuItem(
                value: screen,
                child: Text(screen),
              ),
          ],
          onChanged: _selectStart,
        ),
        const SizedBox(height: 20),
        DropdownButton<String>(
          key: const Key('step3-source-screen'),
          isExpanded: true,
          hint: const Text('Source Screen'),
          value: screens.contains(_sourceScreen) ? _sourceScreen : null,
          items: [
            for (final screen in screens)
              DropdownMenuItem(
                value: screen,
                child: Text(screen),
              ),
          ],
          onChanged: (value) {
            setState(() => _sourceScreen = value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButton<String>(
          key: const Key('step3-destination-screen'),
          isExpanded: true,
          hint: const Text('Destination Screen'),
          value:
              screens.contains(_destinationScreen) ? _destinationScreen : null,
          items: [
            for (final screen in screens)
              DropdownMenuItem(
                value: screen,
                child: Text(screen),
              ),
          ],
          onChanged: (value) {
            setState(() => _destinationScreen = value);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('step3-action-input'),
          controller: _actionController,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Navigation Action',
            hintText: 'e.g. Login Button',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('step3-add-route'),
            onPressed: _addRoute,
            icon: const Icon(Icons.add),
            label: const Text('Add Route'),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Navigation Flow Preview',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Start: ${navigation.startScreen ?? 'Not selected'}',
          key: const Key('step3-start-preview'),
        ),
        for (var i = 0; i < routes.length; i++)
          Card(
            child: ListTile(
              key: Key('step3-route-$i'),
              leading: const Icon(Icons.alt_route),
              title: Text(
                '${routes[i].source} -> ${routes[i].destination}',
              ),
              subtitle: Text('Action: ${routes[i].action}'),
              trailing: IconButton(
                key: Key('step3-remove-route-$i'),
                tooltip: 'Remove route',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeRoute(i),
              ),
            ),
          ),
        if (routes.isEmpty) const Text('No navigation routes added yet.'),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('wizard-next'),
          onPressed: _next,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next: Theme & Brand'),
        ),
        const SizedBox(height: 12),
        const Text('Navigation draft is stored in memory only.'),
      ],
    );
  }
}
