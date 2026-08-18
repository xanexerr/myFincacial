part of finance_app;

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.onAdd,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelected;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    onTap: () => _showOptions(context),
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Category',
        suffixIcon: Icon(Icons.arrow_drop_down),
      ),
      child: Text(selected ?? 'Select or add a category'),
    ),
  );

  Future<void> _showOptions(BuildContext context) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Choose a category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...categories.map(
                  (item) => ListTile(
                    leading: Icon(
                      item == selected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                    ),
                    title: Text(item),
                    onTap: () => Navigator.pop(sheetContext, item),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add new category'),
                  onTap: () => Navigator.pop(sheetContext, '__add__'),
                ),
              ],
            ),
          ),
    );
    if (!context.mounted || value == null) return;
    if (value == '__add__') {
      await onAdd();
    } else {
      onSelected(value);
    }
  }
}
