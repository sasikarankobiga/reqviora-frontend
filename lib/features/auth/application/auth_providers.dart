import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../projects/application/projects_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
