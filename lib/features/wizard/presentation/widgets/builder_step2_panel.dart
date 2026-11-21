import 'package:flutter/material.dart';

import '../../domain/models/wizard_flow.dart';

class BuilderStep2Panel extends StatefulWidget {
  const BuilderStep2Panel({
    super.key,
    required this.flow,
    required this.onNext,
  });

  final WizardFlow flow;
  final VoidCallback onNext;

  @override
  State<BuilderStep2Panel> createState() => _BuilderStep2PanelState();
}

class _BuilderStep2PanelState extends State<BuilderStep2Panel> {
  final _featureController = TextEditingController();
  final _screenController = TextEditingController();

  String? _selectedFeature;
  String? _selectedScreen;

  @override
  void dispose() {
    _featureController.dispose();
    _screenController.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _addFeature() {
    try {
      widget.flow.featureScreens.addFeature(_featureController.text);
      setState(() {
        _selectedFeature = widget.flow.featureScreens.features.last;
        _featureController.clear();
        widget.flow.completedSteps.remove(2);
      });
    } on ArgumentError catch (error) {
      _message(error.message?.toString() ?? 'Invalid feature');
    }
  }

  void _addScreen() {
    try {
      widget.flow.featureScreens.addScreen(_screenController.text);
      setState(() {
        _selectedScreen = widget.flow.featureScreens.screens.last;
        _screenController.clear();
        widget.flow.completedSteps.remove(2);
      });
    } on ArgumentError catch (error) {
      _message(error.message?.toString() ?? 'Invalid screen');
    }
  }

  void _removeFeature(String name) {
    setState(() {
      widget.flow.featureScreens.removeFeature(name);
      if (_selectedFeature == name) _selectedFeature = null;
      widget.flow.completedSteps.remove(2);
    });
  }

  void _removeScreen(String name) {
    setState(() {
      widget.flow.featureScreens.removeScreen(name);
      if (_selectedScreen == name) _selectedScreen = null;
      widget.flow.completedSteps.remove(2);
    });
  }

  void _map() {
    final feature = _selectedFeature;
    final screen = _selectedScreen;

    if (feature == null || screen == null) {
      _message('Select a feature and a screen');
      return;
    }

    try {
      widget.flow.featureScreens.mapFeatureToScreen(
        feature: feature,
        screen: screen,
      );
      setState(() {
        widget.flow.completedSteps.remove(2);
      });
      _message('Feature mapped successfully');
    } on ArgumentError catch (error) {
      _message(error.message?.toString() ?? 'Mapping failed');
    }
  }

  void _next() {
    final draft = widget.flow.featureScreens;

    if (!draft.hasFeaturesAndScreens) {
      _message('Add at least one feature and one screen');
      return;
    }

    final hasMapping = draft.mappings.values.any(
      (screens) => screens.isNotEmpty,
    );

    if (!hasMapping) {
      _message('Map at least one feature to a screen');
      return;
    }

    widget.flow.completeStep(2);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.flow.featureScreens;
    final features = draft.features;
    final screens = draft.screens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Features & Screens',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('step2-feature-input'),
          controller: _featureController,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Feature Name',
            hintText: 'e.g. Authentication',
            border: OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('step2-add-feature'),
            onPressed: _addFeature,
            icon: const Icon(Icons.add),
            label: const Text('Add Feature'),
          ),
        ),
        for (final feature in features)
          ListTile(
            title: Text(feature),
            trailing: IconButton(
              key: Key('step2-remove-feature-$feature'),
              tooltip: 'Remove feature',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeFeature(feature),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Screens',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('step2-screen-input'),
          controller: _screenController,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Screen Name',
            hintText: 'e.g. Login Screen',
            border: OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('step2-add-screen'),
            onPressed: _addScreen,
            icon: const Icon(Icons.add),
            label: const Text('Add Screen'),
          ),
        ),
        for (final screen in screens)
          ListTile(
            title: Text(screen),
            trailing: IconButton(
              key: Key('step2-remove-screen-$screen'),
              tooltip: 'Remove screen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeScreen(screen),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Feature-to-Screen Mapping',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        DropdownButton<String>(
          key: const Key('step2-select-feature'),
          isExpanded: true,
          hint: const Text('Select Feature'),
          value: features.contains(_selectedFeature) ? _selectedFeature : null,
          items: [
            for (final feature in features)
              DropdownMenuItem(
                value: feature,
                child: Text(feature),
              ),
          ],
          onChanged: (value) {
            setState(() => _selectedFeature = value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButton<String>(
          key: const Key('step2-select-screen'),
          isExpanded: true,
          hint: const Text('Select Screen'),
          value: screens.contains(_selectedScreen) ? _selectedScreen : null,
          items: [
            for (final screen in screens)
              DropdownMenuItem(
                value: screen,
                child: Text(screen),
              ),
          ],
          onChanged: (value) {
            setState(() => _selectedScreen = value);
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('step2-map'),
            onPressed: _map,
            icon: const Icon(Icons.link),
            label: const Text('Map Feature to Screen'),
          ),
        ),
        const SizedBox(height: 16),
        for (final entry in draft.mappings.entries)
          for (final screen in entry.value)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text('${entry.key} -> $screen'),
            ),
        const SizedBox(height: 28),
        FilledButton.icon(
          key: const Key('wizard-next'),
          onPressed: _next,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next: Navigation'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Frontend draft only. Backend persistence is pending.',
        ),
      ],
    );
  }
}
