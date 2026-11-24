import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';

/// Static, clearly labelled V1 UX designs for the unimplemented Builder stages.
/// Not substitutes for service-backed authoring and validation.
class BuilderStagePreview extends StatelessWidget {
  const BuilderStagePreview({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => switch (step) {
    2 => const _FeaturesPreview(),
    3 => const _NavigationPreview(),
    4 => const _ThemePreview(),
    5 => const _ComponentsPreview(),
    6 => const _InteractionsPreview(),
    7 => const _AiUiPreview(),
    8 => const _ReviewPreview(),
    _ => const SizedBox.shrink(),
  };
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: SectionTitle(title, subtitle: subtitle));
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.title, this.subtitle, this.priority);
  final String title, subtitle, priority;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13)),
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline, color: AppColors.purple),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        trailing: SmallLabel(priority, color: priority == 'Must' ? AppColors.purple : AppColors.blue),
      ),
    ),
  );
}

class _FeaturesPreview extends StatelessWidget {
  const _FeaturesPreview();
  @override
  Widget build(BuildContext context) => SurfaceCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PreviewHeader('Feature catalogue', 'Example feature and screen mapping'),
      const _FeatureRow('Menu browsing', 'FR-01 · Product discovery', 'Must'),
      const _FeatureRow('Cart management', 'FR-02 · Mock cart workflow', 'Must'),
      const _FeatureRow('Table booking', 'FR-03 · Sample booking form', 'Should'),
      const SizedBox(height: 12),
      const Text('Suggested screens', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final name in ['Home', 'Menu', 'Cart', 'Booking', 'Profile'])
          SmallLabel(name, color: AppColors.blue),
      ]),
      const SizedBox(height: 12),
      const Text('Illustrative only · no requirements saved',
        style: TextStyle(fontSize: 11, color: AppColors.muted)),
    ]));
}

class _NavigationPreview extends StatelessWidget {
  const _NavigationPreview();
  @override
  Widget build(BuildContext context) => SurfaceCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PreviewHeader('Navigation flow editor', 'Example click-through journey'),
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650),
        child: Column(children: [
          const _NavNode(Icons.home_outlined, 'Home screen', true),
          const Icon(Icons.arrow_downward_rounded, color: AppColors.purple),
          const _NavNode(Icons.restaurant_menu_outlined, 'Menu screen', false),
          const Icon(Icons.arrow_downward_rounded, color: AppColors.purple),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Expanded(child: _NavNode(Icons.shopping_bag_outlined, 'Cart', false)),
            SizedBox(width: 12), Expanded(child: _NavNode(Icons.event_outlined, 'Booking', false)),
          ]),
        ]))),
      const SizedBox(height: 15),
      const SmallLabel('Graph design preview · routes not persisted', color: AppColors.muted),
    ]));
}

class _NavNode extends StatelessWidget {
  const _NavNode(this.icon, this.title, this.selected);
  final IconData icon; final String title; final bool selected;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: selected ? const Color(0xFFF2EEFF) : Colors.white,
      border: Border.all(color: selected ? AppColors.purple : AppColors.line),
      borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: AppColors.purple, size: 19),
      const SizedBox(width: 8), Flexible(child: Text(title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
    ]));
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview();
  @override
  Widget build(BuildContext context) => SurfaceCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PreviewHeader('Brand tokens', 'Color, typography and component style samples'),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final c in <(String, Color)>[
          ('Primary', AppColors.purple), ('Secondary', AppColors.blue),
          ('Success', AppColors.green), ('Ink', AppColors.ink),
          ('Canvas', AppColors.background),
        ]) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 78, height: 69, decoration: BoxDecoration(color: c.$2,
            borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line))),
          const SizedBox(height: 6), Text(c.$1,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ]),
      const SizedBox(height: 22),
      const Text('Typography', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      const Text('Make great ideas tangible.',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 23, color: AppColors.ink)),
      const SizedBox(height: 12),
      const Row(children: [SmallLabel('Light mode'), SizedBox(width: 9), SmallLabel('Responsive tokens')]),
    ]));
}

class _ComponentsPreview extends StatelessWidget {
  const _ComponentsPreview();
  @override
  Widget build(BuildContext context) => SurfaceCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PreviewHeader('Components Studio', 'Approved core component families plus supported layouts'),
      LayoutBuilder(builder: (context, constraints) => Wrap(spacing: 12,
        runSpacing: 12, children: [
        for (final c in <(IconData, String)>[
          (Icons.smart_button_rounded, 'Button'), (Icons.input_rounded, 'Input Field'),
          (Icons.crop_square_rounded, 'Card'), (Icons.chat_bubble_outline, 'Dialog'),
          (Icons.tab_rounded, 'Tabs'), (Icons.bar_chart_rounded, 'Chart'),
        ]) SizedBox(width: constraints.maxWidth > 560 ? (constraints.maxWidth - 24) / 3 :
          (constraints.maxWidth - 12) / 2,
          child: Container(padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(color: const Color(0xFFF9F8FE),
              border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(13)),
            child: Column(children: [Icon(c.$1, color: AppColors.purple),
              const SizedBox(height: 9), Text(c.$2,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))]))),
      ])),
    ]));
}

class _InteractionsPreview extends StatelessWidget {
  const _InteractionsPreview();
  @override
  Widget build(BuildContext context) => SurfaceCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PreviewHeader('Interactions & states', 'Preview of rule and state configuration'),
      const _FeatureRow('Submit booking', 'Click → Validate → Mock success state', 'Must'),
      const _FeatureRow('Required field', 'Empty input → Inline validation message', 'Must'),
      const _FeatureRow('Missing data', 'Render a safe empty state', 'Should'),
      const SizedBox(height: 9),
      const Wrap(spacing: 8, runSpacing: 8, children: [
        SmallLabel('Default'), SmallLabel('Loading', color: AppColors.blue),
        SmallLabel('Error', color: Color(0xFFD95B5B)),
        SmallLabel('Success', color: AppColors.green),
        SmallLabel('Disabled', color: AppColors.muted),
      ]),
    ]));
}

class _AiUiPreview extends StatelessWidget {
  const _AiUiPreview();
  @override
  Widget build(BuildContext context) => SurfaceCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PreviewHeader('AI UI Design Workspace', 'Illustrative editor canvas · no generation service attached'),
      Container(decoration: BoxDecoration(color: const Color(0xFFF5F6FC),
        border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.all(14), child: LayoutBuilder(builder: (context, size) {
        final inspector = Container(width: 126, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('INSPECTOR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
            SizedBox(height: 15), SmallLabel('Layout'), SizedBox(height: 10),
            SmallLabel('Color'), SizedBox(height: 10), SmallLabel('Actions'),
          ]));
        final canvas = Container(constraints: const BoxConstraints(minHeight: 275),
          padding: const EdgeInsets.all(15), decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.coffee_rounded, color: AppColors.purple),
              SizedBox(width: 8), Text('Coffee Shop',
                style: TextStyle(fontWeight: FontWeight.w900))]),
            const SizedBox(height: 14), Container(height: 77,
              decoration: BoxDecoration(gradient: const LinearGradient(
                colors: [Color(0xFF7261EE), Color(0xFFA590F8)]),
                borderRadius: BorderRadius.circular(11)),
              child: const Center(child: Text('Your next favorite coffee',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 15)))),
            const SizedBox(height: 15), const Text('Popular items',
              style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 9), Wrap(spacing: 8, children: [
              for (final t in ['Latte', 'Espresso', 'Mocha']) SmallLabel(t),
            ]),
            const SizedBox(height: 14), const SmallLabel('Mock UI rendering only', color: AppColors.muted),
          ]));
        if (size.maxWidth < 450) return canvas;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: canvas), const SizedBox(width: 12), inspector,
        ]);
      })),
    ]));
}

class _ReviewPreview extends StatelessWidget {
  const _ReviewPreview();
  @override
  Widget build(BuildContext context) => SurfaceCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PreviewHeader('Review & Export', 'Preview of revision-bound validation and handover'),
      const _FeatureRow('Requirements coverage', 'Mapped features and screens', 'Must'),
      const _FeatureRow('Navigation validation', 'Route and reachability checks', 'Must'),
      const _FeatureRow('Interaction validation', 'State and action checks', 'Must'),
      const SizedBox(height: 13), const Row(children: [
        Icon(Icons.lock_outline, color: AppColors.purple), SizedBox(width: 11),
        Expanded(child: Text('Immutable approved revision · 19 canonical artifacts + manifest.json',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
      ]),
      const SizedBox(height: 16), const SmallLabel('Approval and export are not connected',
        color: AppColors.muted),
    ]));
}
