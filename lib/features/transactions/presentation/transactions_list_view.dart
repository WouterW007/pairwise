import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pairwise/features/transactions/application/transaction_providers.dart';
import 'package:pairwise/features/transactions/data/transaction.dart';

class TransactionsListView extends ConsumerWidget {
  const TransactionsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsyncValue = ref.watch(transactionsStreamProvider);

    return transactionsAsyncValue.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text('No transactions found yet.'),
            ),
          );
        }

        return ListView.builder(
          // --- FIXES ARE HERE ---
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // --- END FIXES ---
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            return TransactionListTile(transaction: tx);
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

// (The TransactionListTile widget is unchanged)
class TransactionListTile extends StatelessWidget {
  const TransactionListTile({super.key, required this.transaction});
  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final bool isOutflow = transaction.amount > 0;
    final Color amountColor = isOutflow
        ? Theme.of(context).textTheme.bodyLarge!.color!
        : Colors.green;
    final String sign = isOutflow ? '-' : '+';

    return ListTile(
      leading: Icon(
        transaction.pending
            ? Icons.hourglass_top_rounded
            : Icons.check_circle_rounded,
        color: transaction.pending ? Colors.orange : Colors.green,
        size: 28,
      ),
      title: Text(
        transaction.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        transaction.merchantName ?? transaction.category ?? 'Uncategorized',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$sign\$${transaction.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: amountColor,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat.yMd().format(transaction.date.toLocal()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
