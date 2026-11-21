/// Presentation-only information displayed by the Projects Hub.
/// This is NOT a backend contract, domain model, or API DTO.
enum HubProjectPhase { requirements, blueprint, design }

enum HubProjectFilter { all, inProgress, completed }

enum ProjectsHubStatus { populated, loading, empty, error }

class ProjectHubViewData {
  const ProjectHubViewData({
    required this.id,
    required this.name,
    required this.description,
    required this.updatedLabel,
    required this.phase,
    this.isCompleted = false,
  });

  final String id;
  final String name;
  final String description;
  /// Human-readable label provided by the presentation caller.
  final String updatedLabel;
  final HubProjectPhase phase;
  final bool isCompleted;
}

/// Illustrative content for isolated UI previews/tests ONLY.
/// Never treat these values as projects fetched from a server.
abstract final class ProjectsHubPreviewSamples {
  static const projects = <ProjectHubViewData>[
    ProjectHubViewData(
      id: 'sample-01',
      name: 'Atlas Community Portal',
      description: 'From community needs to a clear digital experience.',
      updatedLabel: 'Edited today',
      phase: HubProjectPhase.design,
    ),
    ProjectHubViewData(
      id: 'sample-02',
      name: 'Studio Booking Flow',
      description: 'A thoughtful appointment and scheduling journey.',
      updatedLabel: 'Edited yesterday',
      phase: HubProjectPhase.blueprint,
    ),
    ProjectHubViewData(
      id: 'sample-03',
      name: 'Field Notes Workspace',
      description: 'Organizing early requirements into actionable ideas.',
      updatedLabel: 'Edited this week',
      phase: HubProjectPhase.requirements,
    ),
    ProjectHubViewData(
      id: 'sample-04',
      name: 'Museum Visitor Guide',
      description: 'An accessible experience mapped from research.',
      updatedLabel: 'Sample archive',
      phase: HubProjectPhase.design,
      isCompleted: true,
    ),
  ];
}
