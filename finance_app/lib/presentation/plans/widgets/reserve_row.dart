part of finance_app;

class ReserveRow extends StatelessWidget {
  const ReserveRow({
    super.key,
    required this.label,
    required this.target,
    required this.current,
  });
  final String label;
  final double target;
  final double current;
  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('${formatMoney(current)} / ${formatMoney(target)}'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress, minHeight: 7),
        ],
      ),
    );
  }
}
