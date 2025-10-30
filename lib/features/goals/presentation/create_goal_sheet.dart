import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/goals/data/goal_repository.dart';

// Local provider to manage the loading state of the "Create" button
final _isLoadingProvider = StateProvider<bool>((ref) => false);

class CreateGoalSheet extends ConsumerStatefulWidget {
  const CreateGoalSheet({super.key});

  @override
  ConsumerState<CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends ConsumerState<CreateGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    // 1. Validate the form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ref.read(_isLoadingProvider.notifier).state = true;

    try {
      // 2. Get the values from the controllers
      final name = _nameController.text.trim();
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

      // 3. Call the repository to create the goal
      await ref.read(goalRepositoryProvider).createGoal(
            name: name,
            targetAmount: amount,
          );

      // 4. Close the sheet on success
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New goal created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 5. Show error on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create goal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(_isLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_isLoadingProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Make the sheet only as tall as needed
          children: [
            const Text(
              'Create a New Shared Goal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                  labelText: 'Goal Name (e.g., Vacation)'),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Please enter a name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration:
                  const InputDecoration(labelText: 'Target Amount (\$)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if ((double.tryParse(value) ?? 0) <= 0) {
                  return 'Amount must be greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _submitForm,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Goal'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
