class PendingFeedbackException implements Exception {
  final String message;
  final String pendingSessionUuid;

  const PendingFeedbackException({
    required this.message,
    required this.pendingSessionUuid,
  });

  @override
  String toString() => message;
}
