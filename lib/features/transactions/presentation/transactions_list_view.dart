import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // We need this for formatting
import 'package:pairwise/features/transactions/application/transaction_providers.dart';
import 'package:pairwise/features/transactions/data/transaction.dart';

class TransactionsListView extends ConsumerWidget {
  const TransactionsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch our new stream provider
    final transactionsAsyncValue = ref.watch(transactionsStreamProvider);

    // 2. Use the .when builder to handle loading/error/data states
    return transactionsAsyncValue.when(
      data: (transactions) {
        // --- Data Loaded Successfully ---
        if (transactions.isEmpty) {
          return const Center(child: Text('No transactions found yet.'));
        }

        // Use ListView.builder for performance
        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            return TransactionListTile(transaction: tx); // Use a custom tile
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading transactions: $error'),
      ),
    );
  }
}

// It's good practice to make the list item its own widget
class TransactionListTile extends StatelessWidget {
  const TransactionListTile({super.key, required this.transaction});
  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    // --- Plaid Logic: Inflows are negative, Outflows are positive ---
    // A purchase of $25.50 has amount: 25.50
    // A refund of $10.00 has amount: -10.00
    final bool isOutflow = transaction.amount > 0;

    // Get the right color for the amount
    final Color amountColor = isOutflow
        ? Theme.of(context).textTheme.bodyLarge!.color!
        : Colors.green;

    // Get the right sign for the amount
    final String sign = isOutflow ? '-' : '+';

    return ListTile(
      // Show if the transaction is pending or posted
      leading: Icon(
        transaction.pending
            ? Icons.hourglass_top_rounded
            : Icons.check_circle_rounded,
        color: transaction.pending ? Colors.orange : Colors.green,
        size: 28,
      ),

      // The main name of the transaction
      title: Text(
        transaction.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),

      // Subtitle can be the merchant or category
      subtitle: Text(
        transaction.merchantName ?? transaction.category ?? 'Uncategorized',
        style: Theme.of(context).textTheme.bodySmall,
      ),

      // Trailing shows the amount and date
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Formatted Amount
          Text(
            '$sign\$${transaction.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: amountColor,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          // Formatted Date (using 'intl' package)
          Text(
            DateFormat.yMd().format(transaction.date.toLocal()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
