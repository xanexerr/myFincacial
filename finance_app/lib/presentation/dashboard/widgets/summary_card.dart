part of finance_app;

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(label),
          Text(
            formatMoney(value),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}
