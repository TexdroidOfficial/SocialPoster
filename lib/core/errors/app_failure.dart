enum FailureKind {
  authRequired,
  tokenRevoked,
  unsupportedAccount,
  unsupportedMedia,
  missingPublicUrl,
  invalidMetadata,
  fileChanged,
  fileUnavailable,
  rateLimited,
  quotaExceeded,
  transientNetwork,
  remoteProcessingFailed,
  providerRejected,
  unknownProviderError,
  cancelled,
}

class AppFailure implements Exception {
  const AppFailure(
    this.kind,
    this.message, {
    this.retryable = false,
    this.providerOperationId,
  });

  final FailureKind kind;
  final String message;
  final bool retryable;
  final String? providerOperationId;

  @override
  String toString() => message;
}
