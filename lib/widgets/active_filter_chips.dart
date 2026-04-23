import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';

class ActiveFilterChips extends StatelessWidget {
  final TransactionProvider provider;

  const ActiveFilterChips({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final state = provider.filterState;
    final chips = <Widget>[];

    if (state.searchQuery.isNotEmpty) {
      chips.add(_buildChip(
        label: '"${state.searchQuery}"',
        onRemove: () => provider.setSearchQuery(''),
      ));
    }

    for (final method in state.paymentMethods) {
      chips.add(_buildChip(
        label: method,
        onRemove: () => provider.togglePaymentMethod(method),
      ));
    }

    if (state.amountRange != null) {
      chips.add(_buildChip(
        label: state.amountRange!.label,
        onRemove: () => provider.setAmountRange(null),
      ));
    }

    if (state.dateRange != null) {
      final fmt = DateFormat('MMM d');
      final label =
          '${fmt.format(state.dateRange!.start)} - ${fmt.format(state.dateRange!.end)}';
      chips.add(_buildChip(
        label: label,
        onRemove: () => provider.setDateRange(null, null),
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: chips),
    );
  }

  Widget _buildChip({required String label, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
