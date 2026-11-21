import '../../../projects/domain/models/project_draft.dart';
import 'feature_screen_draft.dart';
import 'navigation_draft.dart';
import 'theme_brand_draft.dart';

class WizardFlow {
  WizardFlow({required this.draft});

  final ProjectDraft draft;

  // Frontend-only Theme & Brand settings for Builder Step 4.
  final ThemeBrandDraft themeBrand = ThemeBrandDraft();

  // In-memory Step 2 draft shared across Builder navigation.
  final FeatureScreenDraft featureScreens = FeatureScreenDraft();

  // Shared frontend-only navigation draft for Builder Step 3.
  late final NavigationDraft navigation = NavigationDraft(
    featureScreens: featureScreens,
  );

  // In-memory Step 2 draft shared across Builder navigation.

  static const stepNames = <String>[
    'Identity & Audience',
    'Features & Screens',
    'Navigation',
    'Theme & Brand',
    'Components & Layout',
    'Interactions & States',
    'AI UI Design Workspace',
    'Review & Preview',
  ];

  final Set<int> completedSteps = <int>{};
  final Set<int> visitedSteps = <int>{1};

  int get totalSteps => stepNames.length;

  double get completionProgress => completedSteps.length / totalSteps;

  void visitStep(int step) {
    _validateStep(step);
    visitedSteps.add(step);
  }

  void completeStep(int step) {
    _validateStep(step);
    completedSteps.add(step);
    visitedSteps.add(step);
  }

  bool isComplete(int step) => completedSteps.contains(step);

  static String nameOf(int step) {
    if (step < 1 || step > stepNames.length) {
      throw RangeError.range(step, 1, stepNames.length, 'step');
    }
    return stepNames[step - 1];
  }

  void _validateStep(int step) {
    nameOf(step);
  }
}

class WizardStepRouteData {
  const WizardStepRouteData({
    required this.flow,
    required this.step,
  });

  final WizardFlow flow;
  final int step;
}
