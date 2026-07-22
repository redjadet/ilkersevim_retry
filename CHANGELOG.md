# Changelog

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
