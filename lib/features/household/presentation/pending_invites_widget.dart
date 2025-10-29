import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pairwise/features/household/application/household_providers.dart';
import 'package:pairwise/features/household/data/household_repository.dart';

// We'll use this to manage the loading state of the "Accept" button
final _acceptLoadingProvider = StateProvider<bool>((ref) => false);

class PendingInvitesWidget extends ConsumerWidget {
  const PendingInvitesWidget({super.key});

  Future<void> _onAcceptInvite(
    WidgetRef ref,
    BuildContext context,
    String inviteId,
  ) async {
    ref.read(_acceptLoadingProvider.notifier).state = true;
    try {
      // Call the repository to accept the invite
      await ref.read(householdRepositoryProvider).acceptInvite(inviteId);

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite accepted! You are now in the household.'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the list of pending invites
      ref.invalidate(pendingInvitesProvider);
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept invite: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      ref.read(_acceptLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch our new FutureProvider
    final invitesAsync = ref.watch(pendingInvitesProvider);
    final isAccepting = ref.watch(_acceptLoadingProvider);

    // Use .when to handle the async states
    return invitesAsync.when(
      data: (invites) {
        if (invites.isEmpty) {
          // If no invites, we don't need to show anything
          return const SizedBox.shrink();
        }

        // If we have invites, show them in a list
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Invites:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invites.length,
              itemBuilder: (context, index) {
                final invite = invites[index];

                // Format the date
                final date =
                    DateFormat.yMd().format(invite.createdAt.toLocal());

                return Card(
                  color: Colors.blueGrey[800],
                  child: ListTile(
                    title: const Text(
                      'Household Invite',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'You received an invite on $date.\n(From user: ${invite.inviterId.substring(0, 8)}...)',
                    ),
                    trailing: ElevatedButton(
                      onPressed: isAccepting
                          ? null // Disable button while loading
                          : () => _onAcceptInvite(ref, context, invite.id),
                      child: isAccepting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error loading invites: ${e.toString()}'),
    );
  }
}
