part of finance_app;

class BudgetProgress extends StatelessWidget {
  const BudgetProgress({
    super.key,
    required this.label,
    required this.actual,
    required this.budget,
  });
  final String label;
  final double actual;
  final double budget;

  @override
  Widget build(BuildContext context) {
    final ratio = budget <= 0 ? 0.0 : (actual / budget).clamp(0.0, 1.0);
    final over = actual > budget && budget > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                '${formatMoney(actual)} / ${formatMoney(budget)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: ratio,
            color: over ? Colors.red : Colors.teal,
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}
