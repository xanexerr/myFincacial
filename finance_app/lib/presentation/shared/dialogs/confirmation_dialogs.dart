part of finance_app;

Future<bool> confirmAction(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Confirm'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
    ) ??
    false;

Future<bool> confirmTextDelete(BuildContext context, String name) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmTextDeleteDialog(name: name),
  );
  return result == true;
}

class ConfirmTextDeleteDialog extends StatefulWidget {
  const ConfirmTextDeleteDialog({super.key, required this.name});
  final String name;

  @override
  State<ConfirmTextDeleteDialog> createState() =>
      _ConfirmTextDeleteDialogState();
}

class _ConfirmTextDeleteDialogState extends State<ConfirmTextDeleteDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Delete "${widget.name}"?'),
    content: TextField(
      controller: controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Type confirm to continue'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            () => Navigator.pop(
              context,
              controller.text.trim().toLowerCase() == 'confirm',
            ),
        child: const Text('Delete'),
      ),
    ],
  );
}
