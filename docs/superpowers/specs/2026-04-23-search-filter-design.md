# Transaction Search & Filter

## Overview

Add client-side search and filtering to the transaction list. Search by merchant name, filter by payment method, amount range (presets), and date range (presets + custom). All filters combine with AND logic. Filtering happens in `TransactionProvider` — no Firestore query changes needed.

## Data Model

### FilterState

```dart
class FilterState {
  final String searchQuery;
  final Set<String> paymentMethods;
  final AmountRange? amountRange;
  final DateRange? dateRange;
}
```

- `searchQuery` — case-insensitive contains match against merchant name.
- `paymentMethods` — multi-select. Empty set means no filter.
- `amountRange` — single-select preset. Null means no filter.
- `dateRange` — start/end dates. Both preset chips and custom range resolve to concrete dates. Null means no filter.

### AmountRange Enum

| Value | Range |
|---|---|
| `under500` | 0 - 499.99 |
| `range500to1000` | 500 - 1000 |
| `range1000to5000` | 1000 - 5000 |
| `above5000` | 5000+ |

### DateRange

```dart
class DateRange {
  final DateTime start;
  final DateTime end;
}
```

Preset chips resolve to `DateRange` values:
- **Today** — start of today to now
- **This Week** — Monday of current week to now
- **This Month** — first of current month to now
- **Last 3 Months** — 3 months ago to now
- **Custom Range** — user picks start and end via date pickers

## Provider Changes

### New State

`TransactionProvider` gains a `FilterState _filterState` field, initialized with empty/null defaults (no active filters).

### New Getter: filteredTransactions

Replaces `transactions` as the UI data source. Applies filters in order:

1. Match `searchQuery` against `merchantName` (case-insensitive contains)
2. Filter by `paymentMethods` if non-empty (transaction's payment method must be in the set)
3. Filter by `amountRange` if set (transaction's `totalAmount` must fall within range)
4. Filter by `dateRange` if set (transaction's `date` must be between start and end inclusive)

When no filters are active, returns the full transaction list.

### New Methods

- `setSearchQuery(String query)` — updates search text, calls `notifyListeners()`
- `togglePaymentMethod(String method)` — adds or removes from the set, calls `notifyListeners()`
- `setAmountRange(AmountRange? range)` — sets or clears amount range, calls `notifyListeners()`
- `setDateRange(DateTime? start, DateTime? end)` — sets or clears date range, calls `notifyListeners()`
- `clearFilters()` — resets all filters and search query, calls `notifyListeners()`

### New Getters

- `bool hasActiveFilters` — true if any filter or search query is active
- `int activeFilterCount` — count of active filter categories (for badge on filter button). Counts: search query (0 or 1), payment methods (0 or 1), amount range (0 or 1), date range (0 or 1). Max value is 4.
- `FilterState get filterState` — exposes current filter state for UI to read

## UI: Transaction List Screen

### Layout

```
┌─────────────────────────────────────┐
│  Super App                     ≡    │  AppBar (unchanged)
├─────────────────────────────────────┤
│  [🔍 Search merchant...    ] [⊞•]  │  Search bar + filter button with badge
├─────────────────────────────────────┤
│  [Cash ✕] [Under 500 ✕] [This mo…] │  Active filter chips (only when filters active)
├─────────────────────────────────────┤
│                                     │
│  Transaction cards...               │  Filtered results
│                                     │
└─────────────────────────────────────┘
```

### Search Bar

- `TextField` with search icon prefix, placed above the transaction list
- Filter button with `Icons.filter_list` on the right side of the search bar
- Badge overlay on filter button showing `activeFilterCount` when > 0
- Live search — filters as the user types, no submit button
- Clearing the text field clears the search query

### Filter Button

- Opens the filter bottom sheet on tap
- Shows a small numbered badge when filters are active

### Active Filter Chips

- Horizontal scrollable row of `Chip` widgets below the search bar
- Only visible when `hasActiveFilters` is true
- Each chip shows the filter label and a remove (✕) icon
- Tapping ✕ removes that specific filter
- Chip labels: payment method name, amount range label (e.g., "Under 500"), date label (e.g., "This Month" or "Apr 1 - Apr 15")

## UI: Filter Bottom Sheet

### Layout

```
┌─────────────────────────────────────┐
│  Filters                  Clear All │
├─────────────────────────────────────┤
│  Payment Method                     │
│  [Cash] [Card] [Mobile Banking]     │  Multi-select chips
│  [Other]                            │
├─────────────────────────────────────┤
│  Amount Range                       │
│  [Under 500] [500-1000]             │  Single-select chips
│  [1000-5000] [5000+]                │
├─────────────────────────────────────┤
│  Date Range                         │
│  [Today] [This Week] [This Month]   │  Single-select chips
│  [Last 3 Months] [Custom Range]     │
│                                     │
│  (From: ___  To: ___ )              │  Only shown when Custom Range selected
├─────────────────────────────────────┤
│  [ Apply Filters ]                  │
└─────────────────────────────────────┘
```

### Behavior

- **Payment Method** — multi-select. Tapping a selected chip deselects it.
- **Amount Range** — single-select. Tapping the active chip deselects it (clears amount filter).
- **Date Range** — single-select presets. "Custom Range" reveals two date picker fields (From, To). Tapping the active preset deselects it.
- **Clear All** — resets all selections within the sheet.
- **Apply Filters** — commits the filter selections to the provider and closes the sheet.
- The sheet opens with current filter state pre-selected.

## File Structure

### New Files

| File | Purpose |
|---|---|
| `lib/models/filter_state.dart` | `FilterState` class, `AmountRange` enum, `DateRange` class |
| `lib/widgets/filter_bottom_sheet.dart` | Bottom sheet widget with all filter sections |
| `lib/widgets/active_filter_chips.dart` | Horizontal chip bar showing active filters |

### Modified Files

| File | Change |
|---|---|
| `lib/providers/transaction_provider.dart` | Add filter state, `filteredTransactions` getter, filter methods |
| `lib/screens/transaction_list_screen.dart` | Add search bar + filter button, switch to `filteredTransactions`, show active filter chips |

### Unchanged

Transaction model, repository layer, Firestore queries, auth layer, all other screens.

## Edge Cases

| Scenario | Behavior |
|---|---|
| No results match filters | Show "No transactions match your filters" with a "Clear Filters" button |
| Empty search query | Search inactive, show all (subject to other filters) |
| All filters cleared | Return to full unfiltered list |
| New transaction added while filters active | Appears only if it matches current filters |

## Testing

| Layer | Approach |
|---|---|
| `FilterState` / `AmountRange` / `DateRange` | Unit tests for defaults, range matching |
| `TransactionProvider.filteredTransactions` | Unit tests with mock repo: search matching, each filter type independently, combined AND filters, clear filters |
| Filter bottom sheet | Not unit tested (UI-only, manual verification) |
| Active filter chips | Not unit tested (UI-only, manual verification) |
