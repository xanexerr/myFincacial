part of finance_app;

const currency = 'THB';
const debtRepaymentCategory = 'Repay';
const filesChannel = MethodChannel('com.xan.personal_finance/files');
const defaultBudgets = <String, double>{};

class FinanceDialog extends StatelessWidget {
  const FinanceDialog({super.key, required this.child, this.width = 420});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: child,
    ),
  );
}

// Shared radius scale: small controls, medium fields, large containers, pills.
abstract final class AppRadius {
  static const sm = 6.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const full = 9999.0;
}

const legacyCategoryNames = <String, String>{
  'ค่าเช่า': 'Rent',
  'ค่าอาหาร': 'Food',
  'ค่าเดินทาง': 'Fuel',
  'โทรศัพท์': 'Phone',
  'ท่องเที่ยว': 'Travel',
  'อื่น ๆ': 'Other',
  'เงินเดือน': 'Salary',
  'รายรับอื่น': 'Other income',
};

String migrateCategoryName(String name) => legacyCategoryNames[name] ?? name;

Map<String, double> migrateBudgets(Map<String, dynamic> source) {
  final result = <String, double>{};
  for (final entry in source.entries) {
    final name = migrateCategoryName(entry.key);
    result[name] = (result[name] ?? 0) + (entry.value as num).toDouble();
  }
  return result;
}
