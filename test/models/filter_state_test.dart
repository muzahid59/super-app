import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/models/filter_state.dart';

void main() {
  group('FilterState', () {
    test('default state has no active filters', () {
      const state = FilterState();

      expect(state.searchQuery, '');
      expect(state.paymentMethods, isEmpty);
      expect(state.amountRange, isNull);
      expect(state.dateRange, isNull);
    });

    test('hasActiveFilters is false for default state', () {
      const state = FilterState();

      expect(state.hasActiveFilters, isFalse);
    });

    test('hasActiveFilters is true when searchQuery is set', () {
      const state = FilterState(searchQuery: 'store');

      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is true when paymentMethods is non-empty', () {
      const state = FilterState(paymentMethods: {'Cash'});

      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is true when amountRange is set', () {
      const state = FilterState(amountRange: AmountRange.under500);

      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is true when dateRange is set', () {
      final state = FilterState(
        dateRange: DateRange(
          start: DateTime(2026, 4, 1),
          end: DateTime(2026, 4, 21),
        ),
      );

      expect(state.hasActiveFilters, isTrue);
    });

    test('activeFilterCount counts each active category', () {
      final state = FilterState(
        searchQuery: 'store',
        paymentMethods: const {'Cash', 'Card'},
        amountRange: AmountRange.under500,
        dateRange: DateRange(
          start: DateTime(2026, 4, 1),
          end: DateTime(2026, 4, 21),
        ),
      );

      expect(state.activeFilterCount, 4);
    });

    test('activeFilterCount is 0 for default state', () {
      const state = FilterState();

      expect(state.activeFilterCount, 0);
    });

    test('copyWith replaces specified fields', () {
      const state = FilterState(searchQuery: 'old');
      final updated = state.copyWith(searchQuery: 'new');

      expect(updated.searchQuery, 'new');
      expect(state.searchQuery, 'old');
    });

    test('copyWith preserves unspecified fields', () {
      const state = FilterState(
        searchQuery: 'store',
        paymentMethods: {'Cash'},
      );
      final updated = state.copyWith(amountRange: () => AmountRange.above5000);

      expect(updated.searchQuery, 'store');
      expect(updated.paymentMethods, {'Cash'});
      expect(updated.amountRange, AmountRange.above5000);
    });
  });

  group('AmountRange', () {
    test('under500 matches amounts 0 to 499.99', () {
      expect(AmountRange.under500.matches(0), isTrue);
      expect(AmountRange.under500.matches(499.99), isTrue);
      expect(AmountRange.under500.matches(500), isFalse);
    });

    test('range500to1000 matches amounts 500 to 1000', () {
      expect(AmountRange.range500to1000.matches(500), isTrue);
      expect(AmountRange.range500to1000.matches(750), isTrue);
      expect(AmountRange.range500to1000.matches(1000), isTrue);
      expect(AmountRange.range500to1000.matches(499.99), isFalse);
      expect(AmountRange.range500to1000.matches(1000.01), isFalse);
    });

    test('range1000to5000 matches amounts 1000 to 5000', () {
      expect(AmountRange.range1000to5000.matches(1000), isTrue);
      expect(AmountRange.range1000to5000.matches(3000), isTrue);
      expect(AmountRange.range1000to5000.matches(5000), isTrue);
      expect(AmountRange.range1000to5000.matches(999.99), isFalse);
      expect(AmountRange.range1000to5000.matches(5000.01), isFalse);
    });

    test('above5000 matches amounts above 5000', () {
      expect(AmountRange.above5000.matches(5000.01), isTrue);
      expect(AmountRange.above5000.matches(10000), isTrue);
      expect(AmountRange.above5000.matches(5000), isFalse);
    });

    test('each AmountRange has a display label', () {
      expect(AmountRange.under500.label, 'Under 500');
      expect(AmountRange.range500to1000.label, '500 - 1000');
      expect(AmountRange.range1000to5000.label, '1000 - 5000');
      expect(AmountRange.above5000.label, '5000+');
    });
  });

  group('DateRange', () {
    test('contains returns true for dates within range inclusive', () {
      final range = DateRange(
        start: DateTime(2026, 4, 1),
        end: DateTime(2026, 4, 30),
      );

      expect(range.contains(DateTime(2026, 4, 1)), isTrue);
      expect(range.contains(DateTime(2026, 4, 15)), isTrue);
      expect(range.contains(DateTime(2026, 4, 30)), isTrue);
    });

    test('contains returns false for dates outside range', () {
      final range = DateRange(
        start: DateTime(2026, 4, 1),
        end: DateTime(2026, 4, 30),
      );

      expect(range.contains(DateTime(2026, 3, 31)), isFalse);
      expect(range.contains(DateTime(2026, 5, 1)), isFalse);
    });
  });
}
