import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/accounts/application/account_providers.dart';
import 'package:pairwise/main.dart'; // For supabase client

// This provider will track if a *specific* account is being updated
final _isUpdatingProvider = StateProvider<Set<String>>((ref) => {});

class AccountListTile extends ConsumerWidget {
  const AccountListTile({super.key, required this.account});
  final Account account;

  // This will be called when the user taps the share/unshare button
  Future<void> _toggleVisibility(WidgetRef ref, BuildContext context) async {
    // 1. Get the current loading set and add this account's ID
    final currentLoading = ref.read(_isUpdatingProvider);
    ref.read(_isUpdatingProvider.notifier).state = {
      ...currentLoading,
      account.id
    };

    try {
      // 2. Determine the new visibility state
      final newVisibility =
          account.visibility == 'private' ? 'shared' : 'private';

      // 3. Make the database update
      // This is secure because RLS policy "Enable update for own accounts"
      // will check if auth.uid() == user_id
      await supabase
          .from('accounts')
          .update({'visibility': newVisibility}).eq('id', account.id);

      // 4. Show a success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${account.name} is now ${newVisibility == 'shared' ? 'Shared' : 'Private'}.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // 5. Show an error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // 6. Remove this account from the loading set
      final currentLoading = ref.read(_isUpdatingProvider);
      currentLoading.remove(account.id);
      ref.read(_isUpdatingProvider.notifier).state = {...currentLoading};
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if this *specific* tile is loading
    final isUpdating = ref.watch(_isUpdatingProvider).contains(account.id);

    // Get the correct icon and text based on visibility
    final isShared = account.visibility == 'shared';
    final icon = isShared ? Icons.group : Icons.lock;
    final buttonText = isShared ? 'Unshare' : 'Share';

    return ListTile(
      title: Text(account.name),
      subtitle: Text('**** ${account.mask} (${account.visibility})'),
      leading: Icon(icon),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Balance
          Text(
            account.currentBalance != null
                ? '\$${account.currentBalance!.toStringAsFixed(2)}'
                : 'N/A',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          // Loading spinner or button
          if (isUpdating)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: () => _toggleVisibility(ref, context),
              child: Text(buttonText),
            ),
        ],
      ),
    );
  }
}
