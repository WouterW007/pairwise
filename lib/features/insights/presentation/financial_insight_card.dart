import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/main.dart'; // For supabase client

// This provider will hold the state of our API call
// It's nullable so we know when to show the button vs. the insight
final insightStateProvider =
    StateProvider.autoDispose<AsyncValue<String>?>((ref) {
  return null;
});

class FinancialInsightCard extends ConsumerWidget {
  const FinancialInsightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insightState = ref.watch(insightStateProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your Weekly Insight',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            // This widget will change based on the state
            _buildInsightBody(context, ref, insightState),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<String>? state,
  ) {
    // State 1: Initial (null) - Show the button
    if (state == null) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Get Your Weekly Insight'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () async {
          // Set state to loading
          ref.read(insightStateProvider.notifier).state =
              const AsyncValue.loading();
          try {
            // Call the Edge Function
            final response = await supabase.functions.invoke(
              'get-financial-insights',
            );

            if (response.data == null || response.data['insight'] == null) {
              throw Exception('No insight returned from function.');
            }

            final String insight = response.data['insight'];
            // Set state to data
            ref.read(insightStateProvider.notifier).state =
                AsyncValue.data(insight);
          } catch (e, st) {
            // Set state to error
            ref.read(insightStateProvider.notifier).state =
                AsyncValue.error(e, st);
          }
        },
      );
    }

    // State 2, 3, 4: Use .when to handle loading/error/data
    return state.when(
      data: (insight) => Text(
        insight,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Error: ${e.toString()}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}
