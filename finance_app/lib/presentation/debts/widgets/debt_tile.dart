part of finance_app;

class DebtTile extends StatelessWidget {
  const DebtTile({
    super.key,
    required this.debt,
    required this.store,
    this.archived = false,
  });
  final Debt debt;
  final FinanceStore store;
  final bool archived;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DebtDetailPage(store: store, debt: debt),
            ),
          ),
      leading: Icon(archived ? Icons.inventory_2_outlined : Icons.receipt_long),
      title: Text(debt.name),
      subtitle: Text(
        debt.isPaidOff
            ? 'Complete'
            : debt.totalMonths == 0
            ? 'No payment schedule'
            : '${debt.payments.length}/${debt.totalMonths} months · ${formatMoney(debt.remainingBalance)} remaining',
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
