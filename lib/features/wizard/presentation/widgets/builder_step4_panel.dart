import 'package:flutter/material.dart';

import '../../domain/models/theme_brand_draft.dart';
import '../../domain/models/wizard_flow.dart';

class BuilderStep4Panel extends StatefulWidget {
  const BuilderStep4Panel({
    super.key,
    required this.flow,
    required this.onNext,
  });

  final WizardFlow flow;
  final VoidCallback onNext;

  @override
  State<BuilderStep4Panel> createState() => _BuilderStep4PanelState();
}

class _BuilderStep4PanelState extends State<BuilderStep4Panel> {
  late final TextEditingController _brand;
  late final TextEditingController _primary;
  late final TextEditingController _secondary;

  late ThemePreference _theme;
  late String _font;

  @override
  void initState() {
    super.initState();
    final draft = widget.flow.themeBrand;
    _brand = TextEditingController(text: draft.brandName);
    _primary = TextEditingController(text: draft.primaryColor);
    _secondary = TextEditingController(text: draft.secondaryColor);
    _theme = draft.theme;
    _font = draft.fontFamily;
  }

  @override
  void dispose() {
    _brand.dispose();
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color? _color(String input) {
    final hex = input.trim();

    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return null;
    }

    return Color(
      int.parse(hex.substring(1), radix: 16) | 0xFF000000,
    );
  }

  void _next() {
    try {
      widget.flow.themeBrand.update(
        theme: _theme,
        brandName: _brand.text,
        primaryColor: _primary.text,
        secondaryColor: _secondary.text,
        fontFamily: _font,
      );

      widget.flow.completeStep(4);
      widget.onNext();
    } on ArgumentError catch (error) {
      _showError(error.message?.toString() ?? 'Invalid theme settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _theme == ThemePreference.dark;
    final primaryColor = _color(_primary.text);
    final secondaryColor = _color(_secondary.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Theme & Brand Settings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ThemePreference>(
          key: const Key('step4-theme-mode'),
          initialValue: _theme,
          decoration: const InputDecoration(
            labelText: 'Theme Mode',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final value in ThemePreference.values)
              DropdownMenuItem(
                value: value,
                child: Text(value.name),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _theme = value;
              widget.flow.completedSteps.remove(4);
            });
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('step4-brand-name'),
          controller: _brand,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Brand Name (Optional)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            setState(() => widget.flow.completedSteps.remove(4));
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('step4-primary-color'),
          controller: _primary,
          maxLength: 7,
          decoration: const InputDecoration(
            labelText: 'Primary Color',
            hintText: '#2563EB',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            setState(() => widget.flow.completedSteps.remove(4));
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('step4-secondary-color'),
          controller: _secondary,
          maxLength: 7,
          decoration: const InputDecoration(
            labelText: 'Secondary Color',
            hintText: '#14B8A6',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            setState(() => widget.flow.completedSteps.remove(4));
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('step4-font'),
          initialValue: _font,
          decoration: const InputDecoration(
            labelText: 'Font Family',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final font in ThemeBrandDraft.supportedFonts)
              DropdownMenuItem(
                value: font,
                child: Text(font),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _font = value;
              widget.flow.completedSteps.remove(4);
            });
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Live Theme Preview',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('step4-preview'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _brand.text.trim().isEmpty
                    ? widget.flow.draft.name
                    : _brand.text.trim(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: _font,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    key: const Key('step4-primary-preview'),
                    width: 48,
                    height: 48,
                    color: primaryColor ?? Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Container(
                    key: const Key('step4-secondary-preview'),
                    width: 48,
                    height: 48,
                    color: secondaryColor ?? Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Sample Preview',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: _font,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Font availability depends on installed assets.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('wizard-next'),
          onPressed: _next,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next: Components & Layout'),
        ),
      ],
    );
  }
}
