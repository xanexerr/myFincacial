part of finance_app;

class CategoryBarSummary extends StatelessWidget {
  const CategoryBarSummary({
    super.key,
    required this.title,
    required this.entries,
    required this.color,
    this.embedded = false,
  });
  final String title;
  final List<FinanceEntry> entries;
  final Color color;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final items = categorySummary(entries).take(3).toList();
    final content = Padding(
      padding: const EdgeInsets.only(top: 12),
    
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            if (items.isEmpty)
            const Text('')
            else
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...items.asMap().entries.map((x) {
                final ratio = (x.value.value / items.first.value).clamp(
                  0.2,
                  1.0,
                );
                final barColor = Color.lerp(color, Colors.white, x.key * .12)!;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: LayoutBuilder(
                  builder:
                      (context, constraints) => Stack(
                        children: [
                          Container(
                          height: 24,

                            width: constraints.maxWidth * ratio,
                            decoration: BoxDecoration(
                              color: barColor,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                          SizedBox(
                          height: 24,

                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      x.value.key,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatMoney(x.value.value),
                                    style: const TextStyle(
                                      color: Colors.white,
                                    fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                ),
              );
              }),
          ],
        ),
      );
    return embedded ? content : Card(child: content);
  }
}
