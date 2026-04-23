import 'package:flutter/material.dart';
import '../providers/transaction_provider.dart';

class ActiveFilterChips extends StatelessWidget {
  final TransactionProvider provider;

  const ActiveFilterChips({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
