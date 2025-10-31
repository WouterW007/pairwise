import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/goals/application/goal_providers.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:pairwise/features/goals/data/goal.dart';
import 'package:pairwise/features/goals/presentation/add_contribution_sheet.dart';

class GoalsListView extends ConsumerWidget {
  const GoalsListView({super.key});

  void _showAddContributionSheet(BuildContext context, Goal goal) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => AddContributionSheet(goal: goal),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsStreamProvider);

    return goalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                  'No shared goals yet. Tap the "+" button to create one!'),
            ),
          );
        }

        return ListView.builder(
          // --- FIXES ARE HERE ---
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // --- END FIXES ---
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final goal = goals[index];

            final double percent;
            if (goal.targetAmount == 0) {
              percent = 0.0;
            } else {
              percent =
                  (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
            }

            return Card(
              child: ListTile(
                title: Text(goal.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    LinearPercentIndicator(
                      percent: percent,
                      lineHeight: 8.0,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                      progressColor: Colors.green,
                      barRadius: const Radius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${goal.currentAmount.toStringAsFixed(0)} / \$${goal.targetAmount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                trailing: TextButton(
                  onPressed: () => _showAddContributionSheet(context, goal),
                  child: const Text('Add'),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading goals: $e')),
    );
  }
}
