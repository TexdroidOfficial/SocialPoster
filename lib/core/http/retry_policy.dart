import 'dart:math';

import '../errors/app_failure.dart';

class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 400),
  });

  final int maxAttempts;
  final Duration baseDelay;

  bool shouldRetry(AppFailure failure, int attempt) =>
      attempt < maxAttempts && failure.retryable;

  Duration delayFor(int attempt, {int? retryAfterSeconds, Random? random}) {
    if (retryAfterSeconds != null) return Duration(seconds: retryAfterSeconds);
    final jitter = (random ?? Random()).nextInt(200);
    return Duration(
      milliseconds: baseDelay.inMilliseconds * (1 << attempt) + jitter,
    );
  }
}
