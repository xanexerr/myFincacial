part of finance_app;

class DebtDetailPage extends StatelessWidget {
  const DebtDetailPage({super.key, required this.store, required this.debt});
  final FinanceStore store;
  final Debt debt;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final months = debt.dueMonths();
      return Scaffold(
        appBar: AppBar(
          title: Text(debt.name),
          actions:
              debt.isPaidOff
                  ? null
                  : [
                    IconButton(
                      onPressed: () => deleteDebt(context),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Initial balance ${formatMoney(debt.initialBalance)}'),
                    Text('Paid ${formatMoney(debt.paidTotal)}'),
                    Text(
                      'Estimated remaining ${formatMoney(debt.remainingBalance)}',
                    ),
                    if (debt.note.isNotEmpty) Text(debt.note),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const SectionTitle(title: 'Payment schedule'),
            if (months.isEmpty)
              const EmptyState(text: 'No payment schedule is set')
            else
              ...months.map((month) {
                final payment =
                    debt.payments
                        .where((item) => item.monthKey == month)
                        .firstOrNull;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      payment == null
                          ? Icons.radio_button_unchecked
                          : Icons.check_circle,
                      color: payment == null ? Colors.blueGrey : Colors.green,
                    ),
                    title: Text(monthLabel(DateTime.parse('$month-01'))),
                    subtitle: Text(
                      payment == null
                          ? 'Payment not confirmed'
                          : 'Paid ${formatMoney(payment.amount)}${payment.receiptNumber.isEmpty ? '' : ' · ${payment.receiptNumber}'}',
                    ),
                    trailing:
                        payment == null
                            ? FilledButton(
                              onPressed: () => showPayment(context, month),
                              child: const Text('Pay'),
                            )
                            : const Icon(Icons.done),
                  ),
                );
              }),
          ],
        ),
      );
    },
  );

  Future<void> showPayment(BuildContext context, String month) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PaymentForm(store: store, debt: debt, month: month),
    );
  }

  Future<void> deleteDebt(BuildContext context) async {
    final confirmed = await confirmTextDelete(context, debt.name);
    if (confirmed) {
      await store.removeDebt(debt.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class PaymentForm extends StatefulWidget {
  const PaymentForm({
    super.key,
    required this.store,
    required this.debt,
    required this.month,
  });
  final FinanceStore store;
  final Debt debt;
  final String month;

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  late final TextEditingController amount;
  final receipt = TextEditingController();
  String? receiptFileName;
  DateTime paidAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    amount = TextEditingController(
      text: widget.debt.installment.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    amount.dispose();
    receipt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirm payment · ${monthLabel(DateTime.parse('${widget.month}-01'))}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount paid'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: receipt,
          decoration: const InputDecoration(
            labelText: 'Receipt number (optional)',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: pickPaymentDate,
          icon: const Icon(Icons.calendar_today),
          label: Text('Payment date · ${dateLabel(paidAt)}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: pickImage,
          icon: const Icon(Icons.image_outlined),
          label: Text(
            receiptFileName == null
                ? 'Attach receipt image (optional)'
                : 'Attached: $receiptFileName',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: confirm,
          icon: const Icon(Icons.check),
          label: const Text('Confirm payment'),
        ),
      ],
    ),
  );

  Future<void> pickImage() async {
    final file = await widget.store.pickReceipt();
    if (file != null) setState(() => receiptFileName = file);
  }

  Future<void> pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: paidAt,
    );
    if (picked != null) setState(() => paidAt = picked);
  }

  Future<void> confirm() async {
    final value = double.tryParse(amount.text.replaceAll(',', ''));
    if (value == null || value <= 0) return;
    await widget.store.markDebtPayment(
      debt: widget.debt,
      month: widget.month,
      amount: value,
      paidAt: paidAt,
      receiptNumber: receipt.text.trim(),
      receiptFileName: receiptFileName,
    );
    if (mounted) Navigator.pop(context);
  }
}
