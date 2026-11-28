import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_invitations_repository.dart';
import 'projects_providers.dart';

final projectInvitationsRepositoryProvider = Provider(
  (ref) => ProjectInvitationsRepository(ref.watch(apiClientProvider)),
);
