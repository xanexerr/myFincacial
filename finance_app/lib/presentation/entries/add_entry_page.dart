part of finance_app;

Future<void> showAddEntryDialog(BuildContext context, FinanceStore store) =>
    showDialog<void>(
      context: context,
      builder: (_) => FinanceDialog(child: AddEntryPage(store: store)),
    );

class AddEntryPage extends StatefulWidget {
  const AddEntryPage({super.key, required this.store});
  final FinanceStore store;

  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  EntryType type = EntryType.expense;
  String? category;
  String? categoryError;
  String? amountError;
  DateTime date = DateTime.now();
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    category = widget.store.defaultExpenseCategory;
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        type == EntryType.expense
            ? widget.store.expenseCategories
            : widget.store.incomeCategories;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xff503c74),
          child: const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Add transaction',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 16),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<EntryType>(
                      segments: const [
                        ButtonSegment(
                          value: EntryType.expense,
                          label: Text('Expense'),
                          icon: Icon(Icons.circle_outlined),
                        ),
                        ButtonSegment(
                          value: EntryType.income,
                          label: Text('Income'),
                          icon: Icon(Icons.circle_outlined),
                        ),
                      ],
                      selected: {type},
                      onSelectionChanged:
                          (value) => setState(() {
                            type = value.first;
                            final next =
                                type == EntryType.expense
                                    ? widget.store.expenseCategories
                                    : widget.store.incomeCategories;
                            final preferred =
                                type == EntryType.expense
                                    ? widget.store.defaultExpenseCategory
                                    : widget.store.defaultIncomeCategory;
                            category =
                                next.contains(preferred)
                                    ? preferred
                                    : (next.contains(category)
                                        ? category
                                        : null);
                          }),
                    ),
                    const SizedBox(height: 14),
                    CategorySelector(
                      categories: categories,
                      selected: category,
                      onSelected:
                          (value) => setState(() {
                            category = value;
                            categoryError = null;
                          }),
                      onAdd: addCategory,
                      errorText: categoryError,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        if (amountError != null) {
                          setState(() => amountError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Amount (THB)',
                        prefixText: '฿ ',
                        errorText: amountError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        '${dateLabel(date)}',
                        style: TextStyle(
                          fontSize: 14.0, // Set size in logical pixels
                        ),
                      ),
                      subtitle: Text(
                        'Time · ${timeLabel(date)}',
                        style: TextStyle(
                          fontSize: 14.0, // Set size in logical pixels
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showCupertinoModalPopup<DateTime>(
                            context: context,
                            builder: (pickerContext) => Container(
                              height: 280,
                              color: CupertinoColors.systemBackground.resolveFrom(
                                pickerContext,
                              ),
                              child: SafeArea(
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: CupertinoButton(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        onPressed: () => Navigator.pop(
                                          pickerContext,
                                          date,
                                        ),
                                        child: const Text('Done'),
                                      ),
                                    ),
                                    Expanded(
                                      child: CupertinoDatePicker(
                                        mode: CupertinoDatePickerMode.date,
                                        initialDateTime: date,
                                        minimumDate: DateTime(2020),
                                        maximumDate: DateTime(2035, 12, 31),
                                        onDateTimeChanged: (value) => date = value,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          if (picked != null) {
                            final time = await showCupertinoModalPopup<TimeOfDay>(
                              context: context,
                              builder: (pickerContext) => Container(
                                height: 280,
                                color: CupertinoColors.systemBackground.resolveFrom(
                                  pickerContext,
                                ),
                                child: SafeArea(
                                  child: Column(
                                    children: [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: CupertinoButton(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          onPressed: () => Navigator.pop(
                                            pickerContext,
                                            TimeOfDay.fromDateTime(date),
                                          ),
                                          child: const Text('Done'),
                                        ),
                                      ),
                                      Expanded(
                                        child: CupertinoDatePicker(
                                          mode: CupertinoDatePickerMode.time,
                                          initialDateTime: date,
                                          use24hFormat: true,
                                          onDateTimeChanged: (value) => date = value,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            setState(() {
                              date = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                time?.hour ?? date.hour,
                                time?.minute ?? date.minute,
                              );
                            });
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Save transaction'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> save() async {
    final amount = double.tryParse(amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => amountError = 'กรุณากรอกจำนวนเงินที่ถูกต้อง');
      return;
    }
    if (category == null || category!.trim().isEmpty) {
      setState(() => categoryError = 'กรุณากรอก Category');
      return;
    }
    await widget.store.addEntry(
      FinanceEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: date,
        type: type,
        category: category ?? '',
        amount: amount,
        note: noteController.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> addCategory() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xff2a2433),
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Add category',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 360,
              child: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Category name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xff211d29),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffc9a4f5),
                  foregroundColor: const Color(0xff211d29),
                  minimumSize: const Size(90, 44),
                ),
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Add'),
              ),
            ],
          ),
    );
    if (value == null || value.trim().isEmpty) return;
    final normalized = value.trim();
    if (mounted) {
      setState(() {
        category = normalized;
        categoryError = null;
      });
    }
    await widget.store.addCategory(type, normalized);
  }
}
