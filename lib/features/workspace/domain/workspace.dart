class Workspace {
  const Workspace({required this.projectId, required this.draftId,
    required this.version, required this.projectName, required this.designTargets,
    required this.sections});
  final String projectId;
  final String draftId;
  final int version;
  final String projectName;
  final List<String> designTargets;
  final Map<String, dynamic> sections;
  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
    projectId: json['projectId'] as String,
    draftId: json['draftId'] as String,
    version: json['draftVersion'] as int,
    projectName: json['projectName'] as String? ?? '',
    designTargets: List<String>.from(json['designTargets'] as List? ?? []),
    sections: Map<String, dynamic>.from(json['sections'] as Map? ?? {}),
  );
  List<Map<String, dynamic>> items(String section) =>
    (sections[section] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Map<String, dynamic> fields(String section) =>
    Map<String, dynamic>.from(sections[section] as Map? ?? {});
}
