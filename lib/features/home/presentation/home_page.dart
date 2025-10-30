import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/main.dart'; // To get the supabase client

// Import our providers
import 'package:pairwise/features/accounts/application/account_providers.dart';

// Import our widgets
import 'package:pairwise/features/accounts/presentation/account_list_tile.dart';
import 'package:pairwise/features/plaid/presentation/plaid_link_handler.dart';
import 'package:pairwise/features/transactions/presentation/transactions_list_view.dart';
import 'package:pairwise/features/household/presentation/invite_partner_widget.dart';
import 'package:pairwise/features/household/presentation/pending_invites_widget.dart';

// --- ADD GOALS IMPORTS ---
import 'package:pairwise/features/goals/presentation/goals_list_view.dart';
import 'package:pairwise/features/goals/presentation/create_goal_sheet.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider for the list of accounts
    final accountsAsyncValue = ref.watch(accountsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pairwise Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          )
        ],
      ),
      // --- ADD FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // This shows our new widget as a modal bottom sheet
          showModalBottomSheet(
            context: context,
            builder: (ctx) => const CreateGoalSheet(),
            isScrollControlled: true, // Allows sheet to resize for keyboard
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Create New Goal',
      ),
      // --- END FAB ---
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display the user's ID
              Text('Welcome! User ID: ${supabase.auth.currentUser!.id}'),
              const SizedBox(height: 20),

              // --- HOUSEHOLD SECTION ---
              const PendingInvitesWidget(),
              const InvitePartnerWidget(),
              // --- END HOUSEHOLD SECTION ---

              const SizedBox(height: 30),
              // --- PLAID LINK BUTTON ---
              const Center(
                child: PlaidLinkHandler(),
              ),
              const SizedBox(height: 30),

              // --- ACCOUNTS SECTION ---
              const Text(
                'Your Accounts:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 180, // Fixed height for accounts list
                ),
                child: accountsAsyncValue.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return const Center(
                          child: Text('No accounts linked yet.'));
                    }
                    // Use our new AccountListTile widget
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        return AccountListTile(account: account);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      Center(child: Text('Error loading accounts: $error')),
                ),
              ),
              // --- END ACCOUNTS SECTION ---

              const SizedBox(height: 20),

              // --- GOALS SECTION ---
              const Text(
                'Shared Goals:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200, // Fixed height for goals
                ),
                child: const GoalsListView(),
              ),
              // --- END GOALS SECTION ---

              const SizedBox(height: 20),

              // --- TRANSACTIONS SECTION ---
              const Text(
                'Recent Transactions:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 400, // Fixed height for transactions
                ),
                child: const TransactionsListView(),
              ),
              // --- END TRANSACTIONS SECTION ---
            ],
          ),
        ),
      ),
    );
  }
}
