// lib/features/goals/presentation/goals_list_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/goals/application/goal_providers.dart';
import 'package:percent_indicator/percent_indicator.dart'; // We'll need this soon

class GoalsListView extends ConsumerWidget {
  const GoalsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsStreamProvider);

    return goalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return const Center(
            child: Text('No shared goals yet. Create one!'),
          );
        }

        return ListView.builder(
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final goal = goals[index];
            final percent =
                (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);

            // We'll use a simple ListTile for now
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
                      backgroundColor: Colors.grey[700],
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
                  onPressed: () {
                    // TODO: Implement "Add Contribution"
                  },
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
