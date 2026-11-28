import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/application/projects_providers.dart';
import '../data/repositories/admin_monitoring_repository.dart';

final adminMonitoringRepositoryProvider = Provider<AdminMonitoringRepository>(
  (ref) => AdminMonitoringRepository(ref.watch(apiClientProvider)),
);
