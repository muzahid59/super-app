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

    if (chips.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'Filter by',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 8),
            ...chips,
          ],
        ),
      ),
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
