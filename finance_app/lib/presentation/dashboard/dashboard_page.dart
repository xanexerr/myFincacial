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

  void changePeriod(DashboardPeriod value) {
    setState(() {
      period = value;
    });
  }

  Widget _periodButton() {
    return Container(
      height: 58,
      width: 58,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xff503c74),
        borderRadius: BorderRadius.circular(29),
      ),
      child: MenuAnchor(
        alignmentOffset: const Offset(0, -58),
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Color(0xff241326)),
          minimumSize: const WidgetStatePropertyAll(Size(58, 0)),
          maximumSize: const WidgetStatePropertyAll(Size(58, double.infinity)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
        menuChildren: [
          _periodMenuItem(DashboardPeriod.week, 'W'),
          _periodMenuItem(DashboardPeriod.month, 'M'),
          _periodMenuItem(DashboardPeriod.year, 'Y'),
        ],
        builder:
            (context, controller, child) => GestureDetector(
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              child: Center(
                child: Text(
                  period == DashboardPeriod.week
                      ? 'W'
                      : period == DashboardPeriod.month
                      ? 'M'
                      : 'Y',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Widget _periodMenuItem(DashboardPeriod value, String label) => MenuItemButton(
    onPressed: () => changePeriod(value),
    style: const ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
      minimumSize: WidgetStatePropertyAll(Size(58, 58)),
      maximumSize: WidgetStatePropertyAll(Size(58, 58)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: SizedBox(
      width: 58,
      height: 58,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder:
            (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * -12),
                child: child,
              ),
            ),
        child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xff503c74),
            // border: Border(bottom: BorderSide(color: Color(0x99ffffff))),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );

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
                _periodButton(),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text(
                        'Category summary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<DashboardFilter>(
                        isDense: true,
                        initialValue: filter,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: .45),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        icon: const Icon(Icons.keyboard_arrow_down),
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
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('No Data'),
                  )
                else ...[
                  if (filter != DashboardFilter.expense)
                    CategoryBarSummary(
                      embedded: true,
                      title: 'Income',
                      entries:
                          entries
                              .where((e) => e.type == EntryType.income)
                              .toList(),
                      color: Colors.green,
                    ),
                  if (filter != DashboardFilter.income)
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No Data'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(title: 'Recent transactions'),
                ...entries
                    .take(8)
                    .map((entry) => EntryTile(entry: entry, showTime: true)),
              ],
            ),
          ),
      ],
    );
  }
}
