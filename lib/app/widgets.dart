import 'package:flutter/material.dart';
import 'theme.dart';
import '../l10n/language_settings.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.line),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(subtitle!, style: const TextStyle(color: AppColors.muted)),
            ],
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

class SmallLabel extends StatelessWidget {
  const SmallLabel(
    this.text, {
    super.key,
    this.color = AppColors.purple,
    this.background,
  });
  final String text;
  final Color color;
  final Color? background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.active = false,
    this.label,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool active;
  final String? label;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.purple, size: 22),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            SmallLabel(
              label!,
              color: active ? AppColors.green : AppColors.muted,
            ),
          ],
        ],
      ),
    ),
  );
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    this.eyebrow,
    this.eyebrowWidget,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String? eyebrow;
  final Widget? eyebrowWidget;
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DefaultTextStyle(
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w800,
          color: AppColors.purple,
        ),
        child: eyebrowWidget ?? Text((eyebrow ?? '').toUpperCase()),
      ),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (action != null) action!,
        ],
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted, fontSize: 14),
      ),
    ],
  );
}

class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.error_outline, color: Color(0xFFD64D5B)),
            SizedBox(width: 9),
            Text(
              'Unable to load',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(message, style: const TextStyle(color: AppColors.muted)),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ],
    ),
  );
}

/// Localizes explicitly selected interface headings.
class LocalizedSectionTitle extends StatelessWidget {
  const LocalizedSectionTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SectionTitle(
      localizedLabel(context, title),
      subtitle: subtitle == null ? null : localizedLabel(context, subtitle!),
      trailing: trailing,
    );
  }
}
