part of finance_app;

class PeriodPicker extends StatelessWidget {
  const PeriodPicker({
    super.key,
    required this.period,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.embedded = false,
  });
  final DashboardPeriod period;
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
    return embedded ? content : Card(child: content);
  }
}
