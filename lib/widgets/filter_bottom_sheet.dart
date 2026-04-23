import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/filter_state.dart';
import '../providers/transaction_provider.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Set<String> _selectedPaymentMethods;
  late AmountRange? _selectedAmountRange;
  late DateRange? _selectedDateRange;
  String? _selectedDatePreset;

  static const _paymentMethods = ['Cash', 'Card', 'Mobile Banking', 'Other'];
  static const _datePresets = [
    'Today',
    'This Week',
    'This Month',
    'Last 3 Months',
    'Custom Range',
  ];

  @override
  void initState() {
    super.initState();
    final state = context.read<TransactionProvider>().filterState;
    _selectedPaymentMethods = Set<String>.from(state.paymentMethods);
    _selectedAmountRange = state.amountRange;
    _selectedDateRange = state.dateRange;
  }

  DateRange _resolvePreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case 'Today':
        return DateRange(start: today, end: now);
      case 'This Week':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateRange(start: monday, end: now);
      case 'This Month':
        return DateRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case 'Last 3 Months':
        return DateRange(
          start: DateTime(now.year, now.month - 3, now.day),
          end: now,
        );
      default:
        return DateRange(start: today, end: now);
    }
  }

  void _applyFilters() {
    final provider = context.read<TransactionProvider>();

    final currentMethods = provider.filterState.paymentMethods;
    if (!_setEquals(_selectedPaymentMethods, currentMethods)) {
      for (final m in currentMethods) {
        if (!_selectedPaymentMethods.contains(m)) {
          provider.togglePaymentMethod(m);
        }
      }
      for (final m in _selectedPaymentMethods) {
        if (!currentMethods.contains(m)) {
          provider.togglePaymentMethod(m);
        }
      }
    }

    provider.setAmountRange(_selectedAmountRange);

    if (_selectedDateRange != null) {
      provider.setDateRange(
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );
    } else {
      provider.setDateRange(null, null);
    }

    Navigator.pop(context);
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    return a.length == b.length && a.containsAll(b);
  }

  void _clearAll() {
    setState(() {
      _selectedPaymentMethods = {};
      _selectedAmountRange = null;
      _selectedDateRange = null;
      _selectedDatePreset = null;
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _selectedDateRange != null
          ? DateTimeRange(
              start: _selectedDateRange!.start,
              end: _selectedDateRange!.end,
            )
          : null,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = DateRange(
          start: picked.start,
          end: picked.end,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Method',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paymentMethods.map((method) {
                  final selected = _selectedPaymentMethods.contains(method);
                  return FilterChip(
                    label: Text(method),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _selectedPaymentMethods.remove(method);
                        } else {
                          _selectedPaymentMethods.add(method);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Amount Range',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AmountRange.values.map((range) {
                  final selected = _selectedAmountRange == range;
                  return ChoiceChip(
                    label: Text(range.label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedAmountRange = selected ? null : range;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Date Range',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _datePresets.map((preset) {
                  final selected = _selectedDatePreset == preset;
                  return ChoiceChip(
                    label: Text(preset),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _selectedDatePreset = null;
                          _selectedDateRange = null;
                        } else {
                          _selectedDatePreset = preset;
                          if (preset == 'Custom Range') {
                            _pickCustomRange();
                          } else {
                            _selectedDateRange = _resolvePreset(preset);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
