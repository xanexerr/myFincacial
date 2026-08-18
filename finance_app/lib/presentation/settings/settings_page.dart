part of finance_app;

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.onThemeModeChanged,
  });
  final FinanceStore store;
  final VoidCallback onThemeModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController savingsController;

  @override
  void initState() {
    super.initState();
    savingsController = TextEditingController(
      text: widget.store.currentSavings.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    savingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
    children: [
      // const SectionTitle(title: 'Local data'),
      // const Card(
      //   child: ListTile(
      //     leading: Icon(Icons.lock_outline),
      //     title: Text('Offline mode'),
      //     subtitle: Text(

      //     ),
      //   ),
      // ),
      const SizedBox(height: 12),
      const SectionTitle(title: 'Appearance'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            initialValue: widget.store.themeMode,
            decoration: const InputDecoration(
              labelText: 'Theme mode',
              prefixIcon: Icon(Icons.brightness_6_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System default')),
              DropdownMenuItem(value: 'light', child: Text('Light mode')),
              DropdownMenuItem(value: 'dark', child: Text('Dark mode')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              await widget.store.setThemeMode(value);
              widget.onThemeModeChanged();
            },
          ),
        ),
      ),
      const SizedBox(height: 12),
      const SectionTitle(title: 'Savings'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: savingsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Current savings (THB)',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  final value = double.tryParse(
                    savingsController.text.replaceAll(',', ''),
                  );
                  if (value == null) return;
                  await widget.store.updateSavings(value);
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Savings updated')),
                    );
                },
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const SectionTitle(title: 'Category manage'),
      CategoryManager(store: widget.store),
      const SizedBox(height: 12),
      const SectionTitle(title: 'Backup / Restore'),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Export Backup'),
              subtitle: const Text(
                'Export data and receipts as a .xanbackup file',
              ),
              onTap: () async {
                final ok = await widget.store.exportBackup();
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Backup exported' : 'Backup cancelled or failed',
                      ),
                    ),
                  );
              },
            ),
            SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Import Backup'),
              subtitle: const Text('Restore app data from a backup file'),
              onTap: () async {
                final allow = await confirmAction(
                  context,
                  'Importing a backup will replace current data. Continue?',
                );
                if (!allow) return;
                final ok = await widget.store.importBackup();
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Backup restored' : 'Import failed'),
                    ),
                  );
              },
            ),
            ListTile(
          leading: Icon(Icons.phone_android),
              title: Text('Version 0.3.3'),
          subtitle: Text(
                'Your data stays on this device and is never uploaded',
          ),
            ),
          ],
        ),
      ),
    ],
  );
}
