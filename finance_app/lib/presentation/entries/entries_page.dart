part of finance_app;

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key, required this.store});
  final FinanceStore store;

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

enum EntryPeriod { year, month, week, day }

enum EntryGrouping { week, day }

class _EntriesPageState extends State<EntriesPage> {
  EntryPeriod period = EntryPeriod.day;
  EntryGrouping grouping = EntryGrouping.day;
  EntryType? type;
  DateTime anchor = DateTime.now();

  Future<void> _showFilterPopup() async {
    var selectedPeriod = period;
    var selectedGrouping = grouping;
    var selectedType = type;
    var selectedAnchor = anchor;

    await showDialog<void>(
      context: context,
      builder:
          (sheetContext) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(sheetContext).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: SizedBox(
                width: 420,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: const Color(0xff503c74),
                    child: const Row(
                      children: [
                        Icon(Icons.filter_alt, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Filter',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  StatefulBuilder(
                builder:
                    (context, setSheetState) => SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      20,
                      16,
                      16 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 2),
                          DropdownButtonFormField<EntryPeriod>(
                            initialValue: selectedPeriod,
                            decoration: const InputDecoration(
                              labelText: 'Period',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: EntryPeriod.year,
                                child: Text('Year'),
                              ),
                              DropdownMenuItem(
                                value: EntryPeriod.month,
                                child: Text('Month'),
                              ),
                              DropdownMenuItem(
                                value: EntryPeriod.week,
                                child: Text('Week'),
                              ),
                              DropdownMenuItem(
                                value: EntryPeriod.day,
                                child: Text('Day'),
                              ),
                            ],
                            onChanged:
                                (value) => setSheetState(
                                  () => selectedPeriod = value!,
                                ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<EntryType?>(
                            initialValue: selectedType,
                            decoration: const InputDecoration(labelText: 'Type'),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All')),
                              DropdownMenuItem(
                                value: EntryType.income,
                                child: Text('Income'),
                              ),
                              DropdownMenuItem(
                                value: EntryType.expense,
                                child: Text('Expense'),
                              ),
                            ],
                            onChanged:
                                (value) => setSheetState(
                                  () => selectedType = value,
                                ),
                          ),
                          const SizedBox(height: 10),
                          if (selectedPeriod == EntryPeriod.day)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: sheetContext,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                  initialDate: selectedAnchor,
                                );
                                if (picked != null) {
                                  setSheetState(() => selectedAnchor = picked);
                                }
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                'Day · ${dateLabel(selectedAnchor)}',
                              ),
                            )
                          else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: selectedAnchor.year,
                                    decoration: const InputDecoration(
                                      labelText: 'Year',
                                    ),
                                    items:
                                        availableYears(widget.store)
                                            .map(
                                              (year) => DropdownMenuItem(
                                                value: year,
                                                child: Text('$year'),
                                              ),
                                            )
                                            .toList(),
                                    onChanged:
                                        (year) => setSheetState(() {
                                          if (year != null) {
                                            selectedAnchor = DateTime(
                                              year,
                                              selectedAnchor.month,
                                              selectedAnchor.day,
                                            );
                                          }
                                        }),
                                  ),
                                ),
                                if (selectedPeriod == EntryPeriod.month) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      initialValue: selectedAnchor.month,
                                      decoration: const InputDecoration(
                                        labelText: 'Month',
                                      ),
                                      items: List.generate(
                                        12,
                                        (index) => DropdownMenuItem(
                                          value: index + 1,
                                          child: Text(_shortMonthNames[index]),
                                        ),
                                      ),
                                      onChanged:
                                          (month) => setSheetState(() {
                                            if (month != null) {
                                              selectedAnchor = DateTime(
                                                selectedAnchor.year,
                                                month,
                                                1,
                                              );
                                            }
                                          }),
                                    ),
                                  ),
                                ],
                                if (selectedPeriod == EntryPeriod.week) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Previous week',
                                          onPressed:
                                              () => setSheetState(
                                                () => selectedAnchor =
                                                    startOfWeek(
                                                      selectedAnchor.subtract(
                                                        const Duration(days: 7),
                                                      ),
                                                    ),
                                              ),
                                          icon: const Icon(
                                            Icons.chevron_left,
                                          ),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              _weekRangeLabel(selectedAnchor),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Next week',
                                          onPressed:
                                              () => setSheetState(
                                                () => selectedAnchor =
                                                    startOfWeek(
                                                      selectedAnchor.add(
                                                        const Duration(days: 7),
                                                      ),
                                                    ),
                                              ),
                                          icon: const Icon(
                                            Icons.chevron_right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          if (selectedPeriod == EntryPeriod.month) ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<EntryGrouping>(
                              initialValue: selectedGrouping,
                              decoration: const InputDecoration(
                                labelText: 'Group by',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: EntryGrouping.week,
                                  child: Text('Week'),
                                ),
                                DropdownMenuItem(
                                  value: EntryGrouping.day,
                                  child: Text('Day'),
                                ),
                              ],
                              onChanged:
                                  (value) => setSheetState(
                                    () => selectedGrouping = value!,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                period = selectedPeriod;
                                grouping = selectedGrouping;
                                type = selectedType;
                                anchor = selectedAnchor;
                              });
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Apply filter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
    );
  }

  String _weekRangeLabel(DateTime date) {
    final start = startOfWeek(date);
    final end = start.add(const Duration(days: 6));
    if (start.year != end.year) {
      return '${start.day} ${_shortMonthNames[start.month - 1]} ${start.year} - '
          '${end.day} ${_shortMonthNames[end.month - 1]} ${end.year}';
    }
    return '${start.day} ${_shortMonthNames[start.month - 1]} - '
        '${end.day} ${_shortMonthNames[end.month - 1]} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final start =
        period == EntryPeriod.year
            ? DateTime(anchor.year)
            : period == EntryPeriod.week
            ? startOfWeek(anchor)
            : period == EntryPeriod.day
            ? DateTime(anchor.year, anchor.month, anchor.day)
            : DateTime(anchor.year, anchor.month);
    final end =
        period == EntryPeriod.year
            ? DateTime(anchor.year + 1)
            : period == EntryPeriod.week
            ? start.add(const Duration(days: 7))
            : period == EntryPeriod.day
            ? start.add(const Duration(days: 1))
            : DateTime(anchor.year, anchor.month + 1);
    final entries = store.inRange(start, end, type: type)
      ..sort((a, b) => b.date.compareTo(a.date));
    final income = entries
        .where((entry) => entry.type == EntryType.income)
        .fold<double>(0, (total, entry) => total + entry.amount);
    final expense = entries
        .where((entry) => entry.type == EntryType.expense)
        .fold<double>(0, (total, entry) => total + entry.amount);
    final netBalance = income - expense;
    final groups = <String, List<FinanceEntry>>{};
    for (final e in entries) {
      final key =
          period == EntryPeriod.day
              ? dateLabel(e.date)
              : grouping == EntryGrouping.week
              ? '${monthLabel(e.date)} - Week ${((e.date.day - 1) ~/ 7) + 1}'
              : dateLabel(e.date);
      groups.putIfAbsent(key, () => []).add(e);
    }
    final groupEntries = groups.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: entries.isEmpty ? 2 : groupEntries.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _TransactionSummary(
            income: income,
            expense: expense,
            netBalance: netBalance,
          );
        }
        if (index == 1) return const SizedBox(height: 8);
        if (entries.isEmpty) {
          return const EmptyState(text: 'No transactions in this period');
        }
        final group = groupEntries[index - 2];
        return Card(
          // margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
                // padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: group.key),
                    ...group.value.asMap().entries.expand(
                      (item) => [
                        Dismissible(
                          key: ValueKey(item.value.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: const Color(0xffa51d35),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss:
                              (_) => confirmDelete(
                                context,
                                item.value.category,
                              ),
                          onDismissed: (_) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) store.removeEntry(item.value.id);
                            });
                          },
                          child: EntryTile(entry: item.value, store: store),
                        ),
                        if (item.key < group.value.length - 1)
                          const Divider(height: 1),
                      ],
                    ),
                  ],
                ),
          ),
        );
      },
    );
  }
}

class _TransactionSummary extends StatelessWidget {
  const _TransactionSummary({
    required this.income,
    required this.expense,
    required this.netBalance,
  });

  final double income;
  final double expense;
  final double netBalance;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          Expanded(child: _SummaryItem('Income', income, Colors.green)),
          Expanded(child: _SummaryItem('Expense', expense, Colors.red)),
          Expanded(
            child: _SummaryItem(
              'Net balance',
              netBalance,
              netBalance >= 0 ? Colors.blue : Colors.deepOrange,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem(this.label, this.amount, this.color);
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Text(
          formatMoney(amount),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    ],
  );
}
