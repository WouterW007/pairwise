import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/goals/data/goal.dart';
import 'package:pairwise/features/goals/data/goal_repository.dart';

// Local provider to manage the loading state of the "Add" button
final _isLoadingProvider = StateProvider<bool>((ref) => false);

class AddContributionSheet extends ConsumerStatefulWidget {
  const AddContributionSheet({super.key, required this.goal});
  final Goal goal;

  @override
  ConsumerState<AddContributionSheet> createState() =>
      _AddContributionSheetState();
}

class _AddContributionSheetState extends ConsumerState<AddContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ref.read(_isLoadingProvider.notifier).state = true;

    try {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

      // Call the repository to add the contribution
      await ref.read(goalRepositoryProvider).addContribution(
            goalId: widget.goal.id,
            amount: amount,
          );

      // Close the sheet on success
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Added \$${amount.toStringAsFixed(2)} to ${widget.goal.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add contribution: $e'),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add to ${widget.goal.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration:
                  const InputDecoration(labelText: 'Amount to Add (\$)'),
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
                  : const Text('Add Contribution'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
