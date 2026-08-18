part of finance_app;

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, this.store});
  final FinanceEntry entry;
  final FinanceStore? store;
  @override
  Widget build(BuildContext context) {
    final income = entry.type == EntryType.income;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: store == null ? null : () => showEntryActions(context, store!),
        leading: CircleAvatar(
          backgroundColor: income ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            income ? Icons.add : Icons.remove,
            color: income ? Colors.green : Colors.red,
          ),
        ),
        title: Text(entry.category),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel(entry.date)),
            if (entry.note.isNotEmpty) Text(entry.note),
          ],
        ),
        trailing: Text(
          '${income ? '+' : '-'}${formatMoney(entry.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: income ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ),
    );
  }

  Future<void> showEntryActions(
    BuildContext context,
    FinanceStore store,
  ) async {
    final canSwitch = DateTime.now().difference(entry.date).inHours <= 72;
    final targetType =
        entry.type == EntryType.income ? EntryType.expense : EntryType.income;
    final categories =
        targetType == EntryType.income
            ? store.incomeCategories
            : store.expenseCategories;
    final category = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Move to category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...categories.map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(c),
                      onTap: () => Navigator.pop(sheetContext, c),
                    ),
                  ),
                  if (canSwitch)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Switch to ${targetType.name}'),
                      leading: const Icon(Icons.swap_horiz),
                      onTap: () => Navigator.pop(sheetContext, '__switch__'),
                    ),
                ],
              ),
            ),
          ),
    );
    if (category == null) return;
    final type = category == '__switch__' ? targetType : entry.type;
    final name =
        category == '__switch__'
            ? (type == EntryType.income
                ? store.defaultIncomeCategory
                : store.defaultExpenseCategory)
            : category;
    if (name == null) return;
    await store.updateEntry(
      FinanceEntry(
        id: entry.id,
        date: entry.date,
        type: type,
        category: name,
        amount: entry.amount,
        note: entry.note,
        sourceDebtId: entry.sourceDebtId,
        sourceDebtMonth: entry.sourceDebtMonth,
      ),
    );
  }
}
