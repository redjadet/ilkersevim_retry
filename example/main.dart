import 'package:ilkersevim_retry/ilkersevim_retry.dart';

Future<void> main() async {
  const RetryPolicy policy = RetryPolicy(
    maxAttempts: 3,
    baseDelay: Duration(milliseconds: 1),
    jitter: false,
  );

  Future<void> immediateDelay(final Duration _) async {}

  int attempts = 0;
  final int result = await policy.executeWithRetry<int>(
    action: () async {
      attempts++;
      if (attempts < 3) {
        throw StateError('transient');
      }
      return attempts;
    },
    delay: immediateDelay,
  );

  print('succeeded after $result attempts');
}
