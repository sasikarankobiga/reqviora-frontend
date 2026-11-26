import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';

enum AiJobState { queued, running, completed, failed }

bool _validGuid(String value) =>
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value) &&
    value != '00000000-0000-0000-0000-000000000000';

AiJobState _parseState(dynamic value) {
  return switch (value) {
    'queued' => AiJobState.queued,
    'running' => AiJobState.running,
    'completed' => AiJobState.completed,
    'failed' => AiJobState.failed,
    _ => throw const ApiException(502, 'Invalid AI job state.'),
  };
}

class AiJobStatus {
  const AiJobStatus({
    required this.id,
    required this.state,
    this.ownerId,
    this.result,
  });

  final String id;
  final String? ownerId;
  final AiJobState state;
  final String? result;

  bool get isTerminal =>
      state == AiJobState.completed || state == AiJobState.failed;

  String? get failureMessage =>
      state == AiJobState.failed ? 'AI provider request failed.' : null;
}

class AiJobPollingCancelled implements Exception {
  const AiJobPollingCancelled();

  @override
  String toString() => 'AI job polling cancelled.';
}

class AiJobPollingTimeout implements Exception {
  const AiJobPollingTimeout();

  @override
  String toString() => 'AI job polling timed out.';
}

/// Uses the existing authenticated AIJobsController contract.
/// The server remains authoritative for job ownership.
class AiJobRepository {
  const AiJobRepository(this.api);

  final ApiClient api;

  static const String basePath = '/api/ai/jobs';

  int _captureSession() {
    if (!authSession.authenticated) {
      throw const ApiException(401, 'Sign in to access AI jobs.');
    }

    return authSession.generation;
  }

  void _checkSession(int generation) {
    if (!authSession.authenticated || authSession.generation != generation) {
      throw const ApiException(401, 'The account session changed.');
    }
  }

  Future<AiJobStatus> submit(String prompt) async {
    final generation = _captureSession();
    final value = prompt.trim();

    if (value.isEmpty || value.length > 100000) {
      throw ArgumentError(
        'AI prompt must contain between 1 and 100000 characters.',
      );
    }

    final raw = await api.post(basePath, {'prompt': value});

    _checkSession(generation);

    if (raw is! Map ||
        raw['id'] is! String ||
        !_validGuid(raw['id'] as String) ||
        raw['state'] != 'queued') {
      throw const ApiException(502, 'Invalid AI job receipt.');
    }

    return AiJobStatus(id: raw['id'] as String, state: AiJobState.queued);
  }

  Future<AiJobStatus> getStatus(String jobId) async {
    final generation = _captureSession();

    if (!_validGuid(jobId)) {
      throw ArgumentError('Invalid AI job ID.');
    }

    final raw = await api.get('$basePath/$jobId');

    _checkSession(generation);

    if (raw is! Map) {
      throw const ApiException(502, 'Invalid AI job response.');
    }

    final id = raw['id'];
    final ownerId = raw['ownerId'];

    if (id is! String ||
        id.toLowerCase() != jobId.toLowerCase() ||
        ownerId is! String ||
        !_validGuid(ownerId)) {
      throw const ApiException(502, 'Invalid AI job identity.');
    }

    final state = _parseState(raw['state']);
    final result = raw['result'];
    final error = raw['error'];

    if ((result != null && result is! String) ||
        (error != null && error is! String)) {
      throw const ApiException(502, 'Invalid AI job payload.');
    }

    if (state == AiJobState.completed && result is! String) {
      throw const ApiException(502, 'Completed AI job has no result.');
    }

    return AiJobStatus(
      id: id,
      ownerId: ownerId,
      state: state,
      result: state == AiJobState.completed ? result as String : null,
    );
  }

  /// Polls sequentially, avoiding overlapping HTTP requests.
  /// Cancellation stops observation, not the server-side job.
  Future<AiJobStatus> poll(
    String jobId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 120,
    bool Function()? isCancelled,
    void Function(AiJobStatus)? onStatus,
  }) async {
    final generation = _captureSession();

    if (!_validGuid(jobId)) {
      throw ArgumentError('Invalid AI job ID.');
    }

    if (interval.isNegative || maxAttempts < 1 || maxAttempts > 300) {
      throw ArgumentError('Invalid polling configuration.');
    }

    void ensureActive() {
      _checkSession(generation);

      if (isCancelled?.call() ?? false) {
        throw const AiJobPollingCancelled();
      }
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      ensureActive();

      final status = await getStatus(jobId);

      ensureActive();

      onStatus?.call(status);

      ensureActive();

      if (status.isTerminal) {
        return status;
      }

      if (attempt + 1 < maxAttempts) {
        await Future<void>.delayed(interval);
      }
    }

    throw const AiJobPollingTimeout();
  }
}
