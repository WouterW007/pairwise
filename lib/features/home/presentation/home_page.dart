import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/main.dart'; // To get the supabase client

// Import our providers
import 'package:pairwise/features/accounts/application/account_providers.dart';

// Import our widgets
import 'package:pairwise/features/plaid/presentation/plaid_link_handler.dart';
import 'package:pairwise/features/transactions/presentation/transactions_list_view.dart';

// 1. IMPORT our new household widgets
import 'package:pairwise/features/household/presentation/invite_partner_widget.dart';
import 'package:pairwise/features/household/presentation/pending_invites_widget.dart';
import 'package:pairwise/features/accounts/presentation/account_list_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // 2. Wrap in a SingleChildScrollView
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome! User ID: ${supabase.auth.currentUser!.id}'),
              const SizedBox(height: 20),

              // --- 3. HOUSEHOLD SECTION ---
              const PendingInvitesWidget(),
              const InvitePartnerWidget(),
              // --- END HOUSEHOLD SECTION ---

              const SizedBox(height: 30),
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
                  maxHeight: 180, // You can adjust this height
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
                  }, // <-- **FIX:** CLOSE data block
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator()), // <-- **FIX:** ADD loading handler
                  error: (error, stack) => Center(
                      child: Text(
                          'Error loading accounts: $error')), // <-- **FIX:** ADD error handler
                ),
              ), // <-- **FIX:** CLOSE ConstrainedBox

              // --- FIX: MOVED TRANSACTIONS SECTION OUTSIDE ---
              const SizedBox(height: 20), // Add spacing

              // --- TRANSACTIONS SECTION ---
              const Text(
                'Recent Transactions:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),

              // Give transactions a fixed height
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 400, // Fixed height for transactions
                ),
                child: const TransactionsListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
