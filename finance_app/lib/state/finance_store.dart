part of finance_app;

class FinanceStore extends ChangeNotifier {
  final List<FinanceEntry> entries = [];
  final List<Debt> debts = [];
  Map<String, double> budgets = {};
  List<String> expenseCategories = [];
  List<String> incomeCategories = [];
  String? defaultExpenseCategory;
  String? defaultIncomeCategory;
  String themeMode = 'system';
  double currentSavings = 0;

  static const _filePath =
      '/data/user/0/com.xan.personal_finance/app_flutter/finance_data.json';
  static const _receiptDirectory =
      '/data/user/0/com.xan.personal_finance/app_flutter/receipts';

  Future<File> get _file async {
    final directory = Directory(
      '/data/user/0/com.xan.personal_finance/app_flutter',
    );
    await directory.create(recursive: true);
    return File(_filePath);
  }

  String? receiptPath(String? fileName) =>
      fileName == null || fileName.isEmpty
          ? null
          : '$_receiptDirectory/$fileName';

  Future<void> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) {
        debts.addAll(defaultDebts());
        return;
      }
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      entries
        ..clear()
        ..addAll(
          ((data['entries'] as List<dynamic>?) ?? []).map(
            (item) => FinanceEntry.fromJson(item as Map<String, dynamic>),
          ),
        );
      final savedDebts = data['debts'] as List<dynamic>?;
      debts
        ..clear()
        ..addAll(
          (savedDebts ?? []).map(
            (item) => Debt.fromJson(item as Map<String, dynamic>),
          ),
        );
      // Migrate data created by v0.1, which did not have a debts key yet.
      if (savedDebts == null) debts.addAll(defaultDebts());
      final savedBudgets = data['budgets'] as Map<String, dynamic>?;
      if (savedBudgets != null) {
        budgets = migrateBudgets(savedBudgets);
      }
      expenseCategories =
          List<String>.from(
            (data['expenseCategories'] as List<dynamic>?) ?? const [],
          ).map(migrateCategoryName).toSet().toList();
      incomeCategories =
          List<String>.from(
            (data['incomeCategories'] as List<dynamic>?) ?? const [],
          ).map(migrateCategoryName).toSet().toList();
      currentSavings = (data['currentSavings'] as num?)?.toDouble() ?? 0;
      defaultIncomeCategory = data['defaultIncomeCategory'] as String?;
      themeMode = (data['themeMode'] as String?) ?? 'system';
      defaultExpenseCategory = data['defaultExpenseCategory'] as String?;
    } catch (_) {
      if (debts.isEmpty) debts.addAll(defaultDebts());
    }
    // Categories are user-owned. Existing legacy data remains usable by
    // deriving categories from entries, without restoring hard-coded defaults.
    for (final entry in entries) {
      final list =
          entry.type == EntryType.expense
              ? expenseCategories
              : incomeCategories;
      if (!list.contains(entry.category)) list.add(entry.category);
    }
  }

  Map<String, dynamic> snapshot() => {
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'debts': debts.map((debt) => debt.toJson()).toList(),
    'budgets': budgets,
    'expenseCategories': expenseCategories,
    'incomeCategories': incomeCategories,
    'currentSavings': currentSavings,
    'defaultExpenseCategory': defaultExpenseCategory,
    'defaultIncomeCategory': defaultIncomeCategory,
    'themeMode': themeMode,
  };

  Future<void> save() async {
    final file = await _file;
    await file.writeAsString(jsonEncode(snapshot()));
  }

  Future<void> addEntry(FinanceEntry entry) async {
    entries.add(entry);
    await save();
    notifyListeners();
  }

  Future<void> removeEntry(String id) async {
    final entry = entries.where((item) => item.id == id).firstOrNull;
    if (entry == null) return;
    if (entry.sourceDebtId != null && entry.sourceDebtMonth != null) {
      final debt =
          debts.where((item) => item.id == entry.sourceDebtId).firstOrNull;
      debt?.payments.removeWhere(
        (payment) => payment.monthKey == entry.sourceDebtMonth,
      );
    }
    entries.removeWhere((item) => item.id == id);
    await save();
    notifyListeners();
  }

  Future<void> updateSavings(double value) async {
    currentSavings = value;
    await save();
    notifyListeners();
  }

  Future<void> addCategory(EntryType type, String name) async {
    final list =
        type == EntryType.expense ? expenseCategories : incomeCategories;
    if (name.trim().isEmpty || list.contains(name.trim())) return;
    list.add(name.trim());
    await save();
    notifyListeners();
  }

  Future<bool> renameCategory(
    EntryType type,
    String oldName,
    String newName,
  ) async {
    final list =
        type == EntryType.expense ? expenseCategories : incomeCategories;
    final normalized = newName.trim();
    if (normalized.isEmpty ||
        (list.contains(normalized) && normalized != oldName))
      return false;
    final index = list.indexOf(oldName);
    if (index < 0) return false;
    list[index] = normalized;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.type == type && entry.category == oldName) {
        entries[i] = FinanceEntry(
          id: entry.id,
          date: entry.date,
          type: entry.type,
          category: normalized,
          amount: entry.amount,
          note: entry.note,
          sourceDebtId: entry.sourceDebtId,
          sourceDebtMonth: entry.sourceDebtMonth,
        );
      }
    }
    if (type == EntryType.expense && defaultExpenseCategory == oldName)
      defaultExpenseCategory = normalized;
    if (type == EntryType.income && defaultIncomeCategory == oldName)
      defaultIncomeCategory = normalized;
    if (budgets.containsKey(oldName)) {
      budgets[normalized] = budgets.remove(oldName)!;
    }
    await save();
    notifyListeners();
    return true;
  }

  Future<bool> deleteCategory(EntryType type, String name) async {
    if (entries.any((e) => e.type == type && e.category == name)) return false;
    (type == EntryType.expense ? expenseCategories : incomeCategories).remove(
      name,
    );
    if (type == EntryType.expense && defaultExpenseCategory == name)
      defaultExpenseCategory = null;
    if (type == EntryType.income && defaultIncomeCategory == name)
      defaultIncomeCategory = null;
    await save();
    notifyListeners();
    return true;
  }

  Future<void> setDefaultCategory(EntryType type, String? name) async {
    if (type == EntryType.expense)
      defaultExpenseCategory = name;
    else
      defaultIncomeCategory = name;
    await save();
    notifyListeners();
  }

  Future<void> setThemeMode(String value) async {
    themeMode = value;
    await save();
    notifyListeners();
  }

  Future<void> updateEntry(FinanceEntry entry) async {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) return;
    entries[index] = entry;
    await save();
    notifyListeners();
  }

  Future<void> removeBudget(String category) async {
    budgets.remove(category);
    await save();
    notifyListeners();
  }

  Future<void> setBudget(String category, double amount) async {
    budgets[category] = amount;
    await save();
    notifyListeners();
  }

  Future<void> saveBudget({
    String? previousName,
    required String name,
    required double amount,
  }) async {
    final normalized = name.trim();
    if (previousName != null && previousName != normalized) {
      budgets.remove(previousName);
    }
    budgets[normalized] = amount;
    await save();
    notifyListeners();
  }

  Future<void> addDebt(Debt debt) async {
    debts.add(debt);
    await save();
    notifyListeners();
  }

  Future<void> removeDebt(String id) async {
    debts.removeWhere((debt) => debt.id == id);
    await save();
    notifyListeners();
  }

  Future<void> markDebtPayment({
    required Debt debt,
    required String month,
    required double amount,
    required DateTime paidAt,
    required String receiptNumber,
    String? receiptFileName,
  }) async {
    debt.payments.removeWhere((payment) => payment.monthKey == month);
    debt.payments.add(
      DebtPayment(
        monthKey: month,
        amount: amount,
        paidAt: paidAt,
        receiptNumber: receiptNumber,
        receiptFileName: receiptFileName,
      ),
    );
    final transactionId = 'debt-payment:${debt.id}:$month';
    final transactionIndex = entries.indexWhere(
      (entry) => entry.id == transactionId,
    );
    final transaction = FinanceEntry(
      id: transactionId,
      date: paidAt,
      type: EntryType.expense,
      category: debtRepaymentCategory,
      amount: amount,
      note:
          receiptNumber.isEmpty
              ? 'Debt payment · ${debt.name}'
              : 'Debt payment · ${debt.name} · $receiptNumber',
      sourceDebtId: debt.id,
      sourceDebtMonth: month,
    );
    if (!expenseCategories.contains(debtRepaymentCategory)) {
      expenseCategories.add(debtRepaymentCategory);
    }
    if (transactionIndex == -1) {
      entries.add(transaction);
    } else {
      entries[transactionIndex] = transaction;
    }
    await save();
    notifyListeners();
  }

  Future<String?> pickReceipt() async {
    try {
      return await filesChannel.invokeMethod<String>('pickImage');
    } on PlatformException {
      return null;
    }
  }

  Future<bool> exportBackup() async {
    final attachments = <Map<String, String>>[];
    for (final debt in debts) {
      for (final payment in debt.payments) {
        final name = payment.receiptFileName;
        final path = receiptPath(name);
        if (name != null && path != null && await File(path).exists()) {
          attachments.add({'fileName': name, 'path': path});
        }
      }
    }
    try {
      final result = await filesChannel.invokeMethod<bool>('exportBackup', {
        'content': jsonEncode(snapshot()),
        'attachments': attachments,
      });
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> importBackup() async {
    try {
      final content = await filesChannel.invokeMethod<String>('importBackup');
      if (content == null || content.isEmpty) return false;
      final data = jsonDecode(content) as Map<String, dynamic>;
      entries
        ..clear()
        ..addAll(
          ((data['entries'] as List<dynamic>?) ?? []).map(
            (item) => FinanceEntry.fromJson(item as Map<String, dynamic>),
          ),
        );
      debts
        ..clear()
        ..addAll(
          ((data['debts'] as List<dynamic>?) ?? []).map(
            (item) => Debt.fromJson(item as Map<String, dynamic>),
          ),
        );
      budgets = migrateBudgets(
        (data['budgets'] as Map<String, dynamic>?) ?? defaultBudgets,
      );
      expenseCategories =
          List<String>.from(
            (data['expenseCategories'] as List<dynamic>?) ?? const [],
          ).map(migrateCategoryName).toSet().toList();
      incomeCategories =
          List<String>.from(
            (data['incomeCategories'] as List<dynamic>?) ?? const [],
          ).map(migrateCategoryName).toSet().toList();
      currentSavings = (data['currentSavings'] as num?)?.toDouble() ?? 0;
      defaultExpenseCategory = data['defaultExpenseCategory'] as String?;
      defaultIncomeCategory = data['defaultIncomeCategory'] as String?;
      themeMode = (data['themeMode'] as String?) ?? 'system';
      await save();
      notifyListeners();
      return true;
    } on PlatformException {
      return false;
    } on FormatException {
      return false;
    }
  }

  List<FinanceEntry> inRange(DateTime start, DateTime end, {EntryType? type}) =>
      entries.where((entry) {
        final inDate = !entry.date.isBefore(start) && entry.date.isBefore(end);
        return inDate && (type == null || entry.type == type);
      }).toList();

  double total(DateTime start, DateTime end, EntryType type) => inRange(
    start,
    end,
    type: type,
  ).fold(0, (sum, entry) => sum + entry.amount);

  double get monthlyBudget =>
      budgets.values.fold(0, (sum, value) => sum + value);
  double get essentialBudget => monthlyBudget;
}

List<Debt> defaultDebts() {
  // Keep public builds free of personal financial data.
  return [];
}
