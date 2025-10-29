// lib/features/plaid/application/plaid_linking_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/plaid/data/plaid_repository.dart';

// This provider will manage the state of the Plaid linking process
final plaidLinkingNotifierProvider =
    AutoDisposeAsyncNotifierProvider<PlaidLinkingNotifier, void>(
  PlaidLinkingNotifier.new,
);

class PlaidLinkingNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No initial build work needed, we just wait for a method call
    return;
  }

  /// Triggers the full Plaid link and sync process
  Future<void> linkAndSync({
    required String publicToken,
    // required Map<String, dynamic> metadata, <-- REMOVED
  }) async {
    // 1. Set state to loading
    state = const AsyncLoading();

    // 2. Call the repository and update state based on the result
    state = await AsyncValue.guard(() {
      // Get the repository
      final plaidRepository = ref.read(plaidRepositoryProvider);

      // Call the new chained method
      return plaidRepository.linkAccountAndSync(
        publicToken: publicToken,
        // metadata: metadata, <-- REMOVED
      );
    });
  }

  /// Sets the state to loading (e.g., while waiting for link token)
  void startLoading() {
    state = const AsyncLoading();
  }

  /// Resets the state to idle/success (e.g., after user cancels Plaid)
  void reset() {
    state = const AsyncData(null);
  }
}
