import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_card.dart';
import '../widgets/empty_state.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          if (provider.transactions.isEmpty) {
            return const EmptyState();
          }

          return ListView.builder(
            itemCount: provider.transactions.length,
            itemBuilder: (context, index) {
              final transaction = provider.transactions[index];
              return TransactionCard(
                transaction: transaction,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/edit',
                    arguments: transaction,
                  );
                },
                onDelete: () {
                  provider.deleteTransaction(transaction.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction deleted'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/capture');
        },
        backgroundColor: const Color(0xFF2196F3),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }
}
