class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  bool contains(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return !dayOnly.isBefore(startDay) && !dayOnly.isAfter(endDay);
  }
}

enum AmountRange {
  under500,
  range500to1000,
  range1000to5000,
  above5000;

  String get label {
    switch (this) {
      case AmountRange.under500:
        return 'Under 500';
      case AmountRange.range500to1000:
        return '500 - 1000';
      case AmountRange.range1000to5000:
        return '1000 - 5000';
      case AmountRange.above5000:
        return '5000+';
    }
  }

  bool matches(double amount) {
    switch (this) {
      case AmountRange.under500:
        return amount < 500;
      case AmountRange.range500to1000:
        return amount >= 500 && amount <= 1000;
      case AmountRange.range1000to5000:
        return amount >= 1000 && amount <= 5000;
      case AmountRange.above5000:
        return amount > 5000;
    }
  }
}

class FilterState {
  final String searchQuery;
  final Set<String> paymentMethods;
  final AmountRange? amountRange;
  final DateRange? dateRange;

  const FilterState({
    this.searchQuery = '',
    this.paymentMethods = const {},
    this.amountRange,
    this.dateRange,
  });

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      paymentMethods.isNotEmpty ||
      amountRange != null ||
      dateRange != null;

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.isNotEmpty) count++;
    if (paymentMethods.isNotEmpty) count++;
    if (amountRange != null) count++;
    if (dateRange != null) count++;
    return count;
  }

  FilterState copyWith({
    String? searchQuery,
    Set<String>? paymentMethods,
    AmountRange? Function()? amountRange,
    DateRange? Function()? dateRange,
  }) {
    return FilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      amountRange: amountRange != null ? amountRange() : this.amountRange,
      dateRange: dateRange != null ? dateRange() : this.dateRange,
    );
  }
}
