part of finance_app;

enum EntryType { income, expense }

class FinanceEntry {
  FinanceEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.amount,
    this.note = '',
    this.sourceDebtId,
    this.sourceDebtMonth,
  });

  final String id;
  final DateTime date;
  final EntryType type;
  final String category;
  final double amount;
  final String note;
  final String? sourceDebtId;
  final String? sourceDebtMonth;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'type': type.name,
    'category': category,
    'amount': amount,
    'note': note,
    if (sourceDebtId != null) 'sourceDebtId': sourceDebtId,
    if (sourceDebtMonth != null) 'sourceDebtMonth': sourceDebtMonth,
  };

  factory FinanceEntry.fromJson(Map<String, dynamic> json) => FinanceEntry(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    type: json['type'] == 'income' ? EntryType.income : EntryType.expense,
    category:
        json['sourceDebtId'] != null
            ? debtRepaymentCategory
            : migrateCategoryName(json['category'] as String),
    amount: (json['amount'] as num).toDouble(),
    note: (json['note'] as String?) ?? '',
    sourceDebtId: json['sourceDebtId'] as String?,
    sourceDebtMonth: json['sourceDebtMonth'] as String?,
  );
}

class DebtPayment {
  DebtPayment({
    required this.monthKey,
    required this.amount,
    required this.paidAt,
    this.receiptNumber = '',
    this.receiptFileName,
  });

  final String monthKey;
  final double amount;
  final DateTime paidAt;
  final String receiptNumber;
  final String? receiptFileName;

  Map<String, dynamic> toJson() => {
    'monthKey': monthKey,
    'amount': amount,
    'paidAt': paidAt.toIso8601String(),
    'receiptNumber': receiptNumber,
    'receiptFileName': receiptFileName,
  };

  factory DebtPayment.fromJson(Map<String, dynamic> json) => DebtPayment(
    monthKey: json['monthKey'] as String,
    amount: (json['amount'] as num).toDouble(),
    paidAt: DateTime.parse(json['paidAt'] as String),
    receiptNumber: (json['receiptNumber'] as String?) ?? '',
    receiptFileName: json['receiptFileName'] as String?,
  );
}

class Debt {
  Debt({
    required this.id,
    required this.name,
    required this.initialBalance,
    required this.installment,
    required this.startMonth,
    required this.totalMonths,
    this.dueDay = 1,
    this.note = '',
    List<DebtPayment>? payments,
  }) : payments = payments ?? [];

  final String id;
  final String name;
  final double initialBalance;
  final double installment;
  final String startMonth;
  final int totalMonths;
  final int dueDay;
  final String note;
  final List<DebtPayment> payments;

  List<String> dueMonths() {
    if (totalMonths <= 0 || startMonth.length < 7) return [];
    final start = DateTime.parse('$startMonth-01');
    return List.generate(totalMonths, (index) {
      return monthKey(DateTime(start.year, start.month + index));
    });
  }

  bool isPaid(String key) => payments.any((payment) => payment.monthKey == key);
  bool get isPaidOff => dueMonths().isNotEmpty && dueMonths().every(isPaid);
  double get paidTotal => payments.fold(0, (sum, item) => sum + item.amount);
  double get remainingBalance =>
      (initialBalance - paidTotal).clamp(0, double.infinity);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'initialBalance': initialBalance,
    'installment': installment,
    'startMonth': startMonth,
    'totalMonths': totalMonths,
    'dueDay': dueDay,
    'note': note,
    'payments': payments.map((payment) => payment.toJson()).toList(),
  };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
    id: json['id'] as String,
    name: json['name'] as String,
    initialBalance: (json['initialBalance'] as num).toDouble(),
    installment: (json['installment'] as num).toDouble(),
    startMonth: json['startMonth'] as String,
    totalMonths: (json['totalMonths'] as num).toInt(),
    dueDay: (json['dueDay'] as num?)?.toInt() ?? 1,
    note: (json['note'] as String?) ?? '',
    payments:
        ((json['payments'] as List<dynamic>?) ?? [])
            .map((item) => DebtPayment.fromJson(item as Map<String, dynamic>))
            .toList(),
  );
}
