import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pairwise/features/accounts/application/account_providers.dart';
import 'package:pairwise/features/check_ins/application/check_in_providers.dart';
import 'package:pairwise/features/check_ins/data/check_in_repository.dart';
import 'package:pairwise/features/check_ins/data/check_in_session.dart';
import 'package:pairwise/features/check_ins/presentation/check_in_page.dart';
import 'package:pairwise/features/goals/presentation/create_goal_sheet.dart';
import 'package:pairwise/features/goals/presentation/goals_list_view.dart';
import 'package:pairwise/features/goals/application/goal_providers.dart';
import 'package:pairwise/features/household/application/household_providers.dart';
import 'package:pairwise/features/household/presentation/invite_partner_widget.dart';
import 'package:pairwise/features/household/presentation/pending_invites_widget.dart';
import 'package:pairwise/features/plaid/application/plaid_linking_notifier.dart';
import 'package:pairwise/features/plaid/presentation/plaid_link_handler.dart';
import 'package:pairwise/features/transactions/application/transaction_providers.dart';
import 'package:pairwise/features/transactions/presentation/transactions_list_view.dart';
import 'package:pairwise/main.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listens to Plaid linking state to show loading/errors
    ref.listen<AsyncValue<void>>(
      plaidLinkingNotifierProvider,
      (_, state) {
        if (state.isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Linking account...')),
          );
        }
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error linking account: ${state.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    // Determines if the user is in a household yet.
    final householdIdAsync = ref.watch(householdIdProvider);

    // --- FIX: Removed PlaidLinkHandler wrapper ---
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pairwise'),
        actions: [
          // Sign-out button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                supabase.auth.signOut(), // <-- FIX: 'supabase' is now defined
          ),
        ],
      ),
      body: householdIdAsync.when(
        data: (householdId) {
          // If user has no household, show partner invite UI
          if (householdId == null) {
            return const SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  PendingInvitesWidget(),
                  SizedBox(height: 24),
                  InvitePartnerWidget(),
                ],
              ),
            );
          }
          // If user IS in a household, show the main dashboard
          return _DashboardView(householdId: householdId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(e.toString())),
      ),
    );
  }
}

class _DashboardView extends ConsumerWidget {
  const _DashboardView({required this.householdId});
  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        // --- FIX: Invalidate correct providers ---
        ref.invalidate(accountsStreamProvider);
        ref.invalidate(transactionsStreamProvider);
        ref.invalidate(goalsStreamProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Money Dates (Financial Check-ins) Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Financial Check-ins',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a guided "Money Date" to talk about your finances.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Start a new Money Date'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      // Show loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Starting session...')),
                      );
                      try {
                        final String newSessionId = await ref
                            .read(checkInRepositoryProvider)
                            .createCheckInSession();

                        // Hide spinner & navigate
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  CheckInPage(sessionId: newSessionId),
                            ),
                          );
                        }
                      } catch (e) {
                        // Show error
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 32),
                  Text(
                    'Past Check-ins',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const _PastCheckInsList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Goals Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shared Goals',
                        style: theme.textTheme.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          // --- FIX: Use standard showModalBottomSheet ---
                          showModalBottomSheet(
                            context: context,
                            builder: (ctx) => const CreateGoalSheet(),
                            isScrollControlled:
                                true, // Allows sheet to resize for keyboard
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const GoalsListView(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Transactions Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Recent Transactions',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const TransactionsListView(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- FIX: Added Card for PlaidLinkHandler ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Manage Accounts',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Link a new bank account via Plaid.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: PlaidLinkHandler(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PastCheckInsList extends ConsumerWidget {
  const _PastCheckInsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(checkInSessionsStreamProvider);

    return sessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text('No past check-ins found.'),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final CheckInSession session = sessions[index];
            final String formattedDate =
                DateFormat.yMMMd().format(session.createdAt);

            return ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Money Date'),
              subtitle: Text(formattedDate),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CheckInPage(sessionId: session.id),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: ${e.toString()}')),
    );
  }
}
