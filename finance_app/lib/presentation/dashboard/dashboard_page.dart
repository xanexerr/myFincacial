part of finance_app;

enum DashboardPeriod { week, month, year }

enum DashboardFilter { all, income, expense }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.store});
  final FinanceStore store;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardPeriod period = DashboardPeriod.month;
  DashboardFilter filter = DashboardFilter.all;
  DateTime anchor = DateTime.now();

  ({DateTime start, DateTime end}) get range {
    if (period == DashboardPeriod.week) {
      final start = DateTime(
        anchor.year,
        anchor.month,
        anchor.day - anchor.weekday + 1,
      );
      return (start: start, end: start.add(const Duration(days: 7)));
    }
    if (period == DashboardPeriod.year) {
      final start = DateTime(anchor.year);
      return (start: start, end: DateTime(anchor.year + 1));
    }
    final start = DateTime(anchor.year, anchor.month);
    return (start: start, end: DateTime(anchor.year, anchor.month + 1));
  }

  void move(int amount) {
    if (period == DashboardPeriod.week)
      anchor = anchor.add(Duration(days: amount * 7));
    if (period == DashboardPeriod.month)
      anchor = DateTime(anchor.year, anchor.month + amount);
    if (period == DashboardPeriod.year)
      anchor = DateTime(anchor.year + amount, anchor.month);
    setState(() {});
  }

  Widget _summaryRow(
    String label,
    double value,
    Color color, {
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color),
          const SizedBox(width: 10),
        ],
        Expanded(child: Text(label)),
        Text(
          formatMoney(value),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    ),
  );

  Widget _periodButton(DashboardPeriod value, String label, Color color) {
    final selected = period == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => setState(() => period = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? color : color.withValues(alpha: .18),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRange = range;
    final entries = widget.store.inRange(
      currentRange.start,
      currentRange.end,
      type:
          filter == DashboardFilter.all
              ? null
              : filter == DashboardFilter.income
              ? EntryType.income
              : EntryType.expense,
    )..sort((a, b) => b.date.compareTo(a.date));
    final income = widget.store.total(
      currentRange.start,
      currentRange.end,
      EntryType.income,
    );
    final expense = widget.store.total(
      currentRange.start,
      currentRange.end,
      EntryType.expense,
    );
    final net = income - expense;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _periodButton(
                      DashboardPeriod.year,
                      'Y',
                      const Color(0xff7050a5),
                    ),
                    _periodButton(
                      DashboardPeriod.month,
                      'M',
                      const Color(0xff7050a5),
                    ),
                    _periodButton(
                      DashboardPeriod.week,
                      'W',
                      const Color(0xff7050a5),
                    ),
                  ],
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: PeriodPicker(
                    embedded: true,
                    period: period,
                    label: periodLabel(period, currentRange),
                    onPrevious: () => move(-1),
                    onNext: () => move(1),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _summaryRow('Income', income, Colors.green),
                const Divider(height: 1),
                _summaryRow('Expenses', expense, Colors.red),
                const Divider(height: 1),
                _summaryRow(
                  'Net balance',
                  net,
                  net >= 0 ? Colors.green : Colors.red,
                  icon: net >= 0 ? Icons.check_circle : Icons.warning_amber,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text(
                        'Category summary',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<DashboardFilter>(
                        isDense: true,
                        initialValue: filter,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: DashboardFilter.all,
                            child: Text('All'),
                          ),
                          DropdownMenuItem(
                            value: DashboardFilter.income,
                            child: Text('Income'),
                          ),
                          DropdownMenuItem(
                            value: DashboardFilter.expense,
                            child: Text('Expense'),
                          ),
                        ],
                        onChanged: (value) => setState(() => filter = value!),
                      ),
                    ),
                  ],
                ),
                CategoryBarSummary(
                  embedded: true,
                  title: 'Income',
                  entries:
                      entries.where((e) => e.type == EntryType.income).toList(),
                  color: Colors.green,
                ),
                CategoryBarSummary(
                  embedded: true,
                  title: 'Expenses',
                  entries:
                      entries
                          .where((e) => e.type == EntryType.expense)
                          .toList(),
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const SectionTitle(title: 'Recent transactions'),
        if (entries.isEmpty)
          const EmptyState(text: 'No transactions in this period')
        else
          ...entries.take(8).map((entry) => EntryTile(entry: entry)),
      ],
    );
  }
}
