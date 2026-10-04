# Changelog

## 0.1.7

- Fix dart2js compilation: replace `0x7FFFFFFFFFFFFFFF` attempt guard with
  `Number.MAX_SAFE_INTEGER` (`0x1FFFFFFFFFFFFF`) so linear backoff overflow
  capping still honors `maxDelay` on web.

## 0.1.6

- Fix `RetryPolicy.calculateDelay` returning incorrect delays for very large
  `attempt` values when exponential or linear backoff math overflowed instead of
  honoring `maxDelay`.

## 0.1.5

- Raise minimum SDK to Dart `>=3.13.0`.
- Pin CI to Dart 3.13.2 stable.

## 0.1.4

- Sync README install caret with current release.

## 0.1.3

- Add optional policy-level `shouldRetry` (per-call override still wins).
- Make `transientErrors` / `networkErrors` fail closed: do not retry
  `ArgumentError`, `StateError`, `FormatException`, `TypeError`, or other
  non-timeout errors (only `TimeoutException` by default).
- Document that a null filter still retries every non-cancellation error.

## 0.1.2

- Explain how client-neutral policies centralize backoff, cancellation, and
  testable delay behavior.
- Rewrite package metadata around those use cases.

## 0.1.1

- OIDC publish proof: GitHub Actions → pub.dev via `pub.dev` environment
  (trusted publishing).

## 0.1.0

- Initial release: `RetryPolicy`, `RetryStrategy`, `RetryDelay`, `CancelToken`,
  `CancellationException`, `RetryPolicy.calculateDelay`, and presets
  (`transientErrors`, `networkErrors`).
