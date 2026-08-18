part of finance_app;

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, this.store});
  final FinanceEntry entry;
  final FinanceStore? store;
  @override
  Widget build(BuildContext context) {
    final income = entry.type == EntryType.income;
    return ListTile(
        onTap: () => showEntryDetails(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: income ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            income ? Symbols.payment_arrow_down : Symbols.send_money,
            color: income ? Colors.green : Colors.red,
          ),
        ),
        title: Text(entry.category),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel(entry.date)),
            if (entry.note.isNotEmpty)
              Text(entry.note, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Text(
          '${income ? '+' : '-'}${formatMoney(entry.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: income ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
    );
  }

  Future<void> showEntryDetails(BuildContext context) async {
    final income = entry.type == EntryType.income;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transaction details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detail('Category', entry.category),
            _detail('Type', income ? 'Income' : 'Expense'),
            _detail('Date', dateLabel(entry.date)),
            _detail(
              'Amount',
              '${income ? '+' : '-'}${formatMoney(entry.amount)}',
            ),
            if (entry.note.isNotEmpty) _detail('Note', entry.note),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label\n',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    ),
  );
}
