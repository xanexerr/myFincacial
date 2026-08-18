part of finance_app;

enum DebtCalculationMode { balance, payment }

class AddDebtPage extends StatefulWidget {
  const AddDebtPage({super.key, required this.store});
  final FinanceStore store;

  @override
  State<AddDebtPage> createState() => _AddDebtPageState();
}

class _AddDebtPageState extends State<AddDebtPage> {
  DebtCalculationMode calculationMode = DebtCalculationMode.balance;
  final name = TextEditingController();
  final balance = TextEditingController();
  final months = TextEditingController(text: '12');
  final note = TextEditingController();
  DateTime start = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    months.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add debt')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Debt name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: balance,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText:
                  calculationMode == DebtCalculationMode.balance
                      ? 'Initial balance'
                      : 'Monthly payment',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<DebtCalculationMode>(
            segments: const [
              ButtonSegment(
                value: DebtCalculationMode.balance,
                label: Text('Balance ÷ months'),
              ),
              ButtonSegment(
                value: DebtCalculationMode.payment,
                label: Text('Payment × months'),
              ),
            ],
            selected: {calculationMode},
            onSelectionChanged:
                (value) => setState(() => calculationMode = value.first),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Start month · ${monthLabel(start)}'),
            trailing: TextButton(
              onPressed: chooseStart,
              child: const Text('Choose month'),
            ),
          ),
          TextField(
            controller: months,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Number of installments',
            ),
          ),
          Text(
            'End month · ${monthLabel(end)}\n'
            'Total $totalMonths months · '
            '${calculationMode == DebtCalculationMode.balance ? 'Monthly payment' : 'Initial balance'} '
            '${formatMoney(calculatedSecondaryValue)}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save),
            label: const Text('Save debt'),
          ),
        ],
      ),
    ),
  );

  Future<void> chooseStart() async {
    var year = start.year;
    var month = start.month;
    final picked = await showDialog<DateTime>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Choose start month'),
                  content: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          value: month,
                          isExpanded: true,
                          items: List.generate(
                            12,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text(_shortMonthNames[index]),
                            ),
                          ),
                          onChanged:
                              (value) =>
                                  setDialogState(() => month = value ?? month),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<int>(
                          value: year,
                          isExpanded: true,
                          items: List.generate(
                            16,
                            (index) => DropdownMenuItem(
                              value: 2020 + index,
                              child: Text('${2020 + index}'),
                            ),
                          ),
                          onChanged:
                              (value) =>
                                  setDialogState(() => year = value ?? year),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(
                            dialogContext,
                            DateTime(year, month),
                          ),
                      child: const Text('Select'),
                    ),
                  ],
                ),
          ),
    );
    if (picked != null) {
      setState(() {
        start = DateTime(picked.year, picked.month);
      });
    }
  }

  int get totalMonths => int.tryParse(months.text) ?? 0;
  DateTime get end => DateTime(start.year, start.month + totalMonths - 1);

  double get calculatedSecondaryValue {
    final value = double.tryParse(balance.text.replaceAll(',', '')) ?? 0;
    if (calculationMode == DebtCalculationMode.balance) {
      return totalMonths == 0 ? 0 : value / totalMonths;
    }
    return value * totalMonths;
  }

  Future<void> save() async {
    final enteredValue = double.tryParse(balance.text.replaceAll(',', '')) ?? 0;
    final monthsCount = totalMonths;
    final debt = Debt(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text.trim(),
      initialBalance:
          calculationMode == DebtCalculationMode.balance
              ? enteredValue
              : enteredValue * monthsCount,
      installment:
          calculationMode == DebtCalculationMode.balance
              ? (monthsCount == 0 ? 0 : enteredValue / monthsCount)
              : enteredValue,
      startMonth: monthKey(start),
      totalMonths: monthsCount,
      dueDay: 1,
      note: note.text.trim(),
    );
    if (debt.name.isEmpty || debt.initialBalance <= 0 || monthsCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a debt name and balance')),
      );
      return;
    }
    await widget.store.addDebt(debt);
    if (mounted) Navigator.pop(context);
  }
}
