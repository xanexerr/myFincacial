part of finance_app;

class CategoryManager extends StatelessWidget {
  const CategoryManager({super.key, required this.store});
  final FinanceStore store;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        categorySection(
          context,
          EntryType.income,
          'Income',
          store.incomeCategories,
          store.defaultIncomeCategory,
        ),
        categorySection(
          context,
          EntryType.expense,
          'Expense',
          store.expenseCategories,
          store.defaultExpenseCategory,
        ),
      ],
    ),
  );
  Widget categorySection(
    BuildContext context,
    EntryType type,
    String title,
    List<String> items,
    String? defaultName,
  ) {
    return ExpansionTile(
      title: Text(title),
      children:
          items.map((name) {
            return ListTile(
              title: Text(name),
              leading: Icon(
                name == defaultName ? Icons.star : Icons.label_outline,
              ),
              onTap: () async {
                final controller = TextEditingController(text: name);
                final value = await showDialog<String>(
                  context: context,
                  builder:
                      (dialogContext) => AlertDialog(
                        title: const Text('Rename category'),
                        content: TextField(controller: controller),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed:
                                () => Navigator.pop(
                                  dialogContext,
                                  controller.text,
                                ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                );
                controller.dispose();
                if (value != null)
                  await store.renameCategory(type, name, value);
              },
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Set default',
                    onPressed: () => store.setDefaultCategory(type, name),
                    icon: const Icon(Icons.star_border),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () async {
                      final ok = await store.deleteCategory(type, name);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cannot delete a category that has transactions',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}
