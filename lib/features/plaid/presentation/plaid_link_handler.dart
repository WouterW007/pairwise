// lib/features/plaid/presentation/plaid_link_handler.dart

import 'dart:async'; // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plaid_flutter/plaid_flutter.dart'; // Plaid SDK

// Our notifiers and repositories
import 'package:pairwise/features/plaid/application/plaid_linking_notifier.dart';
import 'package:pairwise/features/plaid/data/plaid_repository.dart';

class PlaidLinkHandler extends ConsumerStatefulWidget {
  const PlaidLinkHandler({super.key});

  @override
  ConsumerState<PlaidLinkHandler> createState() => _PlaidLinkHandlerState();
}

class _PlaidLinkHandlerState extends ConsumerState<PlaidLinkHandler> {
  StreamSubscription<LinkSuccess>? _onSuccessSubscription;
  StreamSubscription<LinkEvent>? _onEventSubscription;
  StreamSubscription<LinkExit>? _onExitSubscription;

  @override
  void initState() {
    super.initState();
    _onSuccessSubscription = PlaidLink.onSuccess.listen(_onSuccess);
    _onEventSubscription = PlaidLink.onEvent.listen(_onEvent);
    _onExitSubscription = PlaidLink.onExit.listen(_onExit);
  }

  @override
  void dispose() {
    _onSuccessSubscription?.cancel();
    _onEventSubscription?.cancel();
    _onExitSubscription?.cancel();
    super.dispose();
  }

  // --- Plaid SDK Callbacks ---

  /// This is the callback from the Plaid SDK on success
  void _onSuccess(LinkSuccess success) {
    print("Plaid Link Success! Firing Notifier...");

    // --- THIS IS THE FIX ---
    // We only pass the publicToken, which is all we need.
    ref.read(plaidLinkingNotifierProvider.notifier).linkAndSync(
          publicToken: success.publicToken,
          // metadata: success.metadata.toJson(), <-- REMOVED
        );
  }

  void _onEvent(LinkEvent event) {
    // You can use this for analytics if you want
    print("Plaid Event: ${event.name}");
  }

  void _onExit(LinkExit exit) {
    // If the user exits with an error, show it
    if (exit.error != null) {
      final String errorMessage = exit.error?.message ?? 'Unknown error';
      print("Plaid Exit with error: $errorMessage");

      if (context.mounted) {
        _showErrorDialog(context, "Plaid exit: $errorMessage");
      }
    } else {
      // User cancelled
      print("Plaid Exit (user cancelled).");
    }

    // In case we were showing a loading state, reset the notifier
    ref.read(plaidLinkingNotifierProvider.notifier).reset();
  }

  // --- Plaid Link Opener ---

  /// This is where you call the Plaid SDK
  Future<void> _launchPlaidLink() async {
    // 1. Set UI to loading state
    ref.read(plaidLinkingNotifierProvider.notifier).startLoading();

    try {
      // 2. Get the link token from our repository
      final linkToken =
          await ref.read(plaidRepositoryProvider).createLinkToken();

      // 3. Configure and open the Plaid SDK
      final configuration = LinkTokenConfiguration(token: linkToken);
      await PlaidLink.create(configuration: configuration);
      PlaidLink.open();
    } catch (e) {
      // 4. If creating the token fails, show an error
      print("Error opening Plaid Link: $e");

      // We MUST use 'mounted' check in async methods
      if (context.mounted) {
        _showErrorDialog(context, "Failed to get link token: ${e.toString()}");
      }

      // Reset the notifier state
      ref.read(plaidLinkingNotifierProvider.notifier).reset();
    }
  }

  // --- Helper Methods to show UI feedback ---
  // (These are the same as before)

  void _showLoadingSpinner(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Text("Linking Account..."),
            ],
          ),
        ),
      ),
    );
  }

  void _hideLoadingSpinner(BuildContext context) {
    // Add a check to make sure the context is still valid
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Link Failed"),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- This is the core logic ---
    // We listen to the notifier to show UI feedback.
    ref.listen<AsyncValue<void>>(plaidLinkingNotifierProvider,
        (previous, next) {
      final isCurrentlyLoading = previous?.isLoading ?? false;

      if (next.isLoading) {
        _showLoadingSpinner(context);
      } else if (next.hasError) {
        // Hide loading dialog if it was open
        if (isCurrentlyLoading) {
          _hideLoadingSpinner(context);
        }
        _showErrorDialog(context, next.error.toString());
      } else if (next.hasValue) {
        // Success!
        if (isCurrentlyLoading) {
          _hideLoadingSpinner(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account linked successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    // The actual button the user taps
    return ElevatedButton(
      // Only allow press if the notifier is not already loading
      onPressed: ref.watch(plaidLinkingNotifierProvider).isLoading
          ? null // Disables button while loading
          : _launchPlaidLink,
      child: const Text("Link Bank Account"),
    );
  }
}
