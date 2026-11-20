import 'package:flutter/material.dart';

/// REQVIORA TASK 008A-UI.
///
/// Reusable presentation-only form controls.
/// No backend contracts, repositories, providers or routing.
///
/// Validation rules are supplied by the caller.
class CreateProjectTextField extends StatelessWidget {
  const CreateProjectTextField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.maxLength,
    super.key,
    this.hint,
    this.helper,
    this.requiredField = false,
    this.minLength = 0,
    this.multiline = false,
    this.enabled = true,
    this.textInputAction,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final int maxLength;
  final String? hint;
  final String? helper;
  final bool requiredField;
  final int minLength;
  final bool multiline;
  final bool enabled;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            requiredField ? 'Required' : 'Optional',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          key: fieldKey,
          controller: controller,
          enabled: enabled,
          maxLength: maxLength,
          maxLines: multiline ? 4 : 1,
          minLines: multiline ? 3 : 1,
          keyboardType:
              multiline ? TextInputType.multiline : TextInputType.text,
          textInputAction: textInputAction ??
              (multiline ? TextInputAction.newline : TextInputAction.next),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: helper,
            helperMaxLines: 3,
            alignLabelWithHint: multiline,
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (rawValue) {
            final value = (rawValue ?? '').trim();

            if (requiredField && value.isEmpty) {
              return '$label is required.';
            }

            if (value.isNotEmpty && value.length < minLength) {
              return '$label must contain at least $minLength characters.';
            }

            if (value.length > maxLength) {
              return '$label cannot exceed $maxLength characters.';
            }

            return null;
          },
        ),
      ],
    );
  }
}

/// The UI exposes string values, not a backend enum.
///
/// Web is the proposed default selected by the parent.
/// This widget does not validate backend-accepted enum values.
class CreateProjectPlatformSelector extends StatelessWidget {
  const CreateProjectPlatformSelector({
    required this.value,
    required this.onChanged,
    super.key,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    const platforms = <(String, String, IconData)>[
      ('web', 'Web', Icons.language_outlined),
      ('mobile', 'Mobile', Icons.smartphone_outlined),
      ('desktop', 'Desktop', Icons.desktop_windows_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Primary Design Platform',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Choose the main platform for your project.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final platform in platforms)
              ChoiceChip(
                key: Key('create-platform-${platform.$1}'),
                label: Text(platform.$2),
                avatar: Icon(
                  platform.$3,
                  size: 18,
                  color: value == platform.$1
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant,
                ),
                selected: value == platform.$1,
                onSelected: enabled
                    ? (selected) {
                        if (selected) {
                          onChanged(platform.$1);
                        }
                      }
                    : null,
                selectedColor: colors.secondaryContainer,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontWeight:
                      value == platform.$1 ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: value == platform.$1 ? colors.primary : colors.outline,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
