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
  EntryPeriod period = EntryPeriod.month;
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
                                    child: DropdownButtonFormField<int>(
                                      initialValue: weekOfYear(selectedAnchor),
                                      decoration: const InputDecoration(
                                        labelText: 'Week',
                                      ),
                                      items: List.generate(
                                        53,
                                        (index) => DropdownMenuItem(
                                          value: index + 1,
                                          child: Text('Week ${index + 1}'),
                                        ),
                                      ),
                                      onChanged:
                                          (week) => setSheetState(() {
                                            if (week != null) {
                                              selectedAnchor = startOfWeek(
                                                DateTime(
                                                  selectedAnchor.year,
                                                  1,
                                                  1,
                                                ).add(
                                                  Duration(
                                                    days: (week - 1) * 7,
                                                  ),
                                                ),
                                              );
                                            }
                                          }),
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
    final groups = <String, List<FinanceEntry>>{};
    for (final e in entries) {
      final key =
          period == EntryPeriod.day
              ? '${e.date.hour < 6
                  ? '1 AM - 6 AM'
                  : e.date.hour < 12
                  ? '6 AM - 12 PM'
                  : e.date.hour < 18
                  ? '1 PM - 6 PM'
                  : '6 PM - 12 AM'} · ${dateLabel(e.date)}'
              : grouping == EntryGrouping.week
              ? '${monthLabel(e.date)} - Week ${((e.date.day - 1) ~/ 7) + 1}'
              : dateLabel(e.date);
      groups.putIfAbsent(key, () => []).add(e);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const EmptyState(text: 'No transactions in this period')
        else
          ...groups.entries.map(
            (group) => Card(
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
            ),
          ),
      ],
    );
  }
}
