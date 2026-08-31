# ilkersevim_retry

Retry policies with backoff, jitter, and cancel tokens. Pure Dart; injectable
`RetryDelay` for testable waits.

## Why use this package?

- Apply the same retry policy to HTTP, storage, or other async work without
  coupling business logic to one client library.
- Control attempt limits, fixed/linear/exponential backoff, jitter, and retry
  filtering in one place.
- Cancel pending retries and inject instant or virtual delays for fast,
  deterministic tests.

This package's `CancelToken` is **not** `package:dio`'s `CancelToken`.

License: [Apache-2.0](LICENSE). Issues:
[github.com/redjadet/ilkersevim_retry/issues](https://github.com/redjadet/ilkersevim_retry/issues).

## Installation

```yaml
dependencies:
  ilkersevim_retry: ^0.1.4
```

Requires Dart `>=3.12.0`.

## Usage

```dart
import 'package:ilkersevim_retry/ilkersevim_retry.dart';

Future<void> main() async {
  final CancelToken cancelToken = CancelToken();
  const RetryPolicy policy = RetryPolicy(maxAttempts: 3);

  // Immediate delay for demos/tests (no wall-clock wait).
  Future<void> immediateDelay(Duration _) async {}

  final int value = await policy.executeWithRetry<int>(
    action: () async => 42,
    cancelToken: cancelToken,
    delay: immediateDelay,
  );

  print(value); // 42

  // Cancel in-flight retries from elsewhere:
  // cancelToken.cancel();
}
```

## API

- `RetryPolicy` / `RetryStrategy` — exponential, linear, or fixed backoff
- `RetryDelay` — injectable wait (`Future.delayed` by default)
- `CancelToken` / `CancellationException` — cooperative cancel (not Dio)
- `RetryPolicy.calculateDelay` — shared delay math
- Presets: `RetryPolicy.transientErrors`, `RetryPolicy.networkErrors`
