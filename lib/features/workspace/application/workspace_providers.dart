import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_session_provider.dart';
import '../../projects/application/projects_providers.dart';
import '../domain/workspace.dart';
import '../data/workspace_repository.dart';
import '../data/browser_source_picker_stub.dart'
    if (dart.library.html) '../data/browser_source_picker.dart'
    as platform_picker;
import '../domain/source_picker.dart';
import '../domain/download_port.dart';
import '../data/browser_download_stub.dart'
    if (dart.library.html) '../data/browser_download.dart'
    as platform_download;

final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => WorkspaceRepository(ref.watch(apiClientProvider)),
);
final workspaceProvider = FutureProvider.family<Workspace, String>((ref, id) {
  ref.watch(authSessionGenerationProvider);
  return ref.watch(workspaceRepositoryProvider).load(id);
});

final sourcePickerProvider = Provider<SourcePicker>(
  (ref) => platform_picker.createSourcePicker(),
);

final downloadPortProvider = Provider<DownloadPort>(
  (ref) => platform_download.createDownloader(),
);
