import 'dart:async';
import 'dart:math';

part 'retry_policy_execute.part.dart';

/// Delay callback used by [RetryPolicy.executeWithRetry] for backoff waits.
///
/// Production default is [Future.delayed]. Callers that need [TimerService]
/// (or other controllable clocks) pass an adapter that completes after
/// [duration]. Cancellation polling still invokes this once per ≤50 ms chunk.
typedef RetryDelay = Future<void> Function(Duration duration);

/// Retry strategy types for different backoff patterns.
enum RetryStrategy {
  /// Exponential backoff: delay = baseDelay * 2^attempt
  exponential,

  /// Linear backoff: delay = baseDelay * attempt
  linear,

  /// Fixed delay: delay = baseDelay (constant)
  fixed,
}

/// A standardized retry policy for consistent retry behavior across features.
///
/// Provides helper methods for cubits to standardize retry behavior
/// (search, chat, charts, etc.) with cancellation support.
///
/// When a [RetryDelay] is passed to [executeWithRetry], backoff waits use it
/// (testable / app-adapted delays). When null, uses [Future.delayed].
class RetryPolicy {
  /// Creates a retry policy with the specified configuration.
  ///
  /// When [shouldRetry] is null, [executeWithRetry] retries every error except
  /// [CancellationException] unless the caller passes a per-call [shouldRetry].
  /// Prefer an explicit filter for non-idempotent work.
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.strategy = RetryStrategy.exponential,
    this.jitter = true,
    this.shouldRetry,
  }) : assert(maxAttempts > 0, 'maxAttempts must be greater than 0');

  /// Maximum number of retry attempts (including initial attempt).
  final int maxAttempts;

  /// Base delay between retries.
  final Duration baseDelay;

  /// Maximum delay cap for exponential/linear backoff.
  final Duration maxDelay;

  /// Retry strategy to use for calculating delays.
  final RetryStrategy strategy;

  /// Whether to add random jitter to delays (helps prevent thundering herd).
  final bool jitter;

  /// Default error filter for this policy. Per-call [executeWithRetry] override
  /// wins when provided.
  final bool Function(Object error)? shouldRetry;

  /// Execute an action with retry logic.
  ///
  /// Returns the result of [action] if successful, or throws the last error
  /// after all retries are exhausted.
  ///
  /// If [cancelToken] is provided and cancelled, throws [CancellationException].
  /// When [delay] is provided, backoff waits use it (enables test / TimerService
  /// adapters). When null, uses [Future.delayed].
  Future<T> executeWithRetry<T>({
    required Future<T> Function() action,
    CancelToken? cancelToken,
    bool Function(Object error)? shouldRetry,
    RetryDelay? delay,
  }) => _retryPolicyExecuteWithRetry(
    this,
    action: action,
    cancelToken: cancelToken,
    shouldRetry: shouldRetry,
    delay: delay,
  );

  /// Shared delay calculation for use by other layers (e.g. HTTP client).
  ///
  /// Uses exponential backoff by default with cap and optional jitter.
  static Duration calculateDelay({
    required int attempt,
    required Duration baseDelay,
    required Duration maxDelay,
    RetryStrategy strategy = RetryStrategy.exponential,
    bool jitter = true,
  }) {
    final Duration cappedDelay = _capDelay(
      _calculateBaseDelay(
        attempt: attempt,
        baseDelay: baseDelay,
        maxDelay: maxDelay,
        strategy: strategy,
      ),
      maxDelay,
    );

    if (jitter && cappedDelay > Duration.zero) {
      return _applyJitter(cappedDelay, maxDelay, Random());
    }

    return cappedDelay;
  }

  static Duration _calculateBaseDelay({
    required int attempt,
    required Duration baseDelay,
    required Duration maxDelay,
    required RetryStrategy strategy,
  }) {
    return switch (strategy) {
      RetryStrategy.exponential => _exponentialBackoffDelay(
        attempt: attempt,
        baseDelay: baseDelay,
        maxDelay: maxDelay,
      ),
      RetryStrategy.linear => _linearBackoffDelay(
        attempt: attempt,
        baseDelay: baseDelay,
        maxDelay: maxDelay,
      ),
      RetryStrategy.fixed => baseDelay,
    };
  }

  static Duration _exponentialBackoffDelay({
    required int attempt,
    required Duration baseDelay,
    required Duration maxDelay,
  }) {
    int milliseconds = baseDelay.inMilliseconds;
    final int maxMs = maxDelay.inMilliseconds;

    for (int i = 0; i < attempt; i++) {
      if (milliseconds >= maxMs) {
        return Duration(milliseconds: milliseconds);
      }

      final int doubled = milliseconds * 2;
      if (doubled < milliseconds) {
        return Duration(milliseconds: maxMs);
      }

      milliseconds = doubled;
    }

    return Duration(milliseconds: milliseconds);
  }

  static Duration _linearBackoffDelay({
    required int attempt,
    required Duration baseDelay,
    required Duration maxDelay,
  }) {
    final int baseMs = baseDelay.inMilliseconds;
    if (baseMs <= 0) {
      return baseDelay;
    }

    final int maxMs = maxDelay.inMilliseconds;
    if (baseMs >= maxMs) {
      return Duration(milliseconds: baseMs);
    }

    if (attempt < 0 || attempt >= 0x7FFFFFFFFFFFFFFF) {
      return Duration(milliseconds: maxMs);
    }

    final int maxAttemptBeforeCap = (maxMs ~/ baseMs) - 1;
    if (attempt > maxAttemptBeforeCap) {
      return Duration(milliseconds: maxMs);
    }

    return Duration(milliseconds: baseMs * (attempt + 1));
  }

  static Duration _capDelay(Duration calculatedDelay, Duration maxDelay) {
    return calculatedDelay > maxDelay ? maxDelay : calculatedDelay;
  }

  static Duration _applyJitter(
    Duration cappedDelay,
    Duration maxDelay,
    Random random,
  ) {
    final int cappedMs = cappedDelay.inMilliseconds;
    final int maxMs = maxDelay.inMilliseconds;
    final int jitterRange = (cappedMs * 0.25).toInt();
    final int jitterOffset =
        random.nextInt((jitterRange * 2) + 1) - jitterRange;
    final int jitteredMs = cappedMs + jitterOffset;
    final int clampedMs = jitteredMs.clamp(0, maxMs);
    return Duration(milliseconds: clampedMs);
  }

  /// Create a default retry policy for transient errors (timeouts).
  ///
  /// Does **not** retry [ArgumentError], [StateError], [FormatException], or
  /// [CancellationException]. Pass a custom [shouldRetry] for HTTP/status codes.
  static const RetryPolicy transientErrors = RetryPolicy(
    maxDelay: Duration(seconds: 10),
    shouldRetry: isTransientError,
  );

  /// Create a retry policy for network-style timeouts with longer delays.
  static const RetryPolicy networkErrors = RetryPolicy(
    baseDelay: Duration(seconds: 2),
    shouldRetry: isTransientError,
  );

  /// Conservative classifier used by [transientErrors] / [networkErrors].
  static bool isTransientError(Object error) {
    if (error is CancellationException) {
      return false;
    }
    if (error is TimeoutException) {
      return true;
    }
    if (error is ArgumentError ||
        error is StateError ||
        error is FormatException ||
        error is TypeError) {
      return false;
    }
    return false;
  }
}

/// Token for cancelling retry operations.
class CancelToken {
  CancelToken();

  bool _isCancelled = false;

  /// Whether this token has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Cancel the retry operation.
  void cancel() {
    _isCancelled = true;
  }
}

/// Exception thrown when a retry operation is cancelled.
class CancellationException implements Exception {
  CancellationException(this.message);

  final String message;

  @override
  String toString() => 'CancellationException: $message';
}
