part of finance_app;

class PlansPage extends StatelessWidget {
  const PlansPage({super.key, required this.store});
  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final active = store.debts.where((debt) => !debt.isPaidOff).toList();
    final archived = store.debts.where((debt) => debt.isPaidOff).toList();
    final essential = store.essentialBudget;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        const SectionTitle(title: 'Emergency fund'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current savings  ${formatMoney(store.currentSavings)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('Planned expenses ${formatMoney(essential)}/month'),
                const SizedBox(height: 12),
                ReserveRow(
                  label: 'Starter buffer',
                  target: 10000,
                  current: store.currentSavings,
                ),
                ReserveRow(
                  label: '6-month reserve',
                  target: essential * 6,
                  current: store.currentSavings,
                ),
                ReserveRow(
                  label: '12-month reserve',
                  target: essential * 12,
                  current: store.currentSavings,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle(title: 'Active debts'),
            FilledButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddDebtPage(store: store),
                    ),
                  ),
              icon: const Icon(Icons.add),
              label: const Text('Add debt'),
            ),
          ],
        ),
        if (active.isEmpty)
          const EmptyState(text: 'No active debts')
        else
          ...active.map((debt) => DebtTile(debt: debt, store: store)),
        const SizedBox(height: 12),
        const SectionTitle(title: 'Paid-off debts'),
        if (archived.isEmpty)
          const EmptyState(text: 'No paid-off debts')
        else
          ...archived.map(
            (debt) => DebtTile(debt: debt, store: store, archived: true),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle(title: 'Budgets'),
            FilledButton.icon(
              onPressed: () => editBudget(context),
              icon: const Icon(Icons.add),
              label: const Text('Add budget'),
            ),
          ],
        ),
        if (store.budgets.isEmpty)
          const EmptyState(text: 'No budgets yet')
        else
          ...store.budgets.entries.map(
            (item) => Card(
              child: ListTile(
                onTap: () => editBudget(context, item),
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(item.key),
                subtitle: Text('${formatMoney(item.value)} / month'),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') {
                      editBudget(context, item);
                    } else {
                      deleteBudget(context, item.key);
                    }
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> editBudget(
    BuildContext context, [
    MapEntry<String, double>? existing,
  ]) async {
    final result = await showDialog<BudgetDraft>(
      context: context,
      builder: (_) => BudgetEditorDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;
    final duplicate =
        store.budgets.containsKey(result.name) && existing?.key != result.name;
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A budget with this name already exists')),
      );
      return;
    }
    await store.saveBudget(
      previousName: existing?.key,
      name: result.name,
      amount: result.amount,
    );
  }

  Future<void> deleteBudget(BuildContext context, String name) async {
    final confirmed = await confirmAction(
      context,
      'Delete the "$name" budget?',
    );
    if (confirmed) await store.removeBudget(name);
  }
}

class BudgetDraft {
  const BudgetDraft({required this.name, required this.amount});
  final String name;
  final double amount;
}

class BudgetEditorDialog extends StatefulWidget {
  const BudgetEditorDialog({super.key, this.existing});
  final MapEntry<String, double>? existing;

  @override
  State<BudgetEditorDialog> createState() => _BudgetEditorDialogState();
}

class _BudgetEditorDialogState extends State<BudgetEditorDialog> {
  late final TextEditingController nameController;
  late final TextEditingController amountController;
  String? error;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.existing?.key ?? '');
    amountController = TextEditingController(
      text: widget.existing?.value.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add budget' : 'Edit budget'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Budget name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monthly amount (THB)',
            errorText: error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Save')),
    ],
  );

  void submit() {
    final name = nameController.text.trim();
    final amount = double.tryParse(amountController.text.replaceAll(',', ''));
    if (name.isEmpty || amount == null || amount < 0) {
      setState(() => error = 'Enter a valid name and amount');
      return;
    }
    Navigator.pop(context, BudgetDraft(name: name, amount: amount));
  }
}
