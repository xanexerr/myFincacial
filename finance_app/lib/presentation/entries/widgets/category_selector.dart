part of finance_app;

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.onAdd,
    this.errorText,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelected;
  final Future<void> Function() onAdd;
  final String? errorText;

  static const _purple = Color(0xff503c74);
  static const _addCategory = '__add__';

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: selected,
    decoration: InputDecoration(
      labelText: 'Category',
      errorText: errorText,
      prefixIcon: const Icon(Icons.circle, size: 12, color: _purple),
    ),
    icon: const SizedBox.shrink(),
    iconSize: 0,
    dropdownColor: Theme.of(context).colorScheme.surface,
    menuMaxHeight: 280,
    items: [
      ...categories.map(
        (item) => DropdownMenuItem(
          value: item,
          child: Row(
            children: [
              const Icon(Icons.circle, size: 10, color: _purple),
              const SizedBox(width: 10),
              Text(item),
            ],
          ),
        ),
      ),
      const DropdownMenuItem(
        value: _addCategory,
        child: Row(
          children: [
            Icon(Icons.circle, size: 10, color: _purple),
            SizedBox(width: 10),
            Text('Add new category'),
          ],
        ),
      ),
    ],
    onChanged: (value) async {
      if (value == _addCategory) {
        await onAdd();
      } else if (value != null) {
        onSelected(value);
      }
    },
  );
}
