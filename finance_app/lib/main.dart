import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const currency = 'THB';
const debtRepaymentCategory = 'Repay';
const filesChannel = MethodChannel('com.xan.personal_finance/files');
const defaultBudgets = <String, double>{};
const legacyCategoryNames = <String, String>{
  'ค่าเช่า': 'Rent',
  'ค่าน้ำไฟ+เน็ต': 'Utilities & Internet',
  'ค่าอาหาร': 'Food',
  'ค่าน้ำมัน': 'Fuel',
  'โทรศัพท์': 'Phone',
  'ผ่อนมือถือ': 'Phone installment',
  'ผ่อนกีตาร์': 'Guitar installment',
  'ท่องเที่ยว': 'Travel',
  'ซ่อมรถ': 'Car maintenance',
  'Codex (จ่ายเอง)': 'Codex (self-paid)',
  'ค่าเทอมที่จ่ายเอง': 'Tuition (self-paid)',
  'อื่น ๆ': 'Other',
  'เงินจากพ่อ': 'Allowance from father',
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
    required String receiptNumber,
    String? receiptFileName,
  }) async {
    final paidAt = DateTime.now();
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LoadingApp());
  final store = FinanceStore();
  await store.load();
  runApp(FinanceApp(store: store));
}

class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoadingScreen(),
  );
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff503c74),
    body: Center(
      child: AnimatedBuilder(
        animation: controller,
        builder:
            (context, _) => CustomPaint(
              painter: LoadingRingPainter(progress: controller.value),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 148,
                    height: 148,
                  ),
                ),
              ),
            ),
      ),
    ),
  );
}

class LoadingRingPainter extends CustomPainter {
  const LoadingRingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final track =
        Paint()
          ..color = const Color(0x55ffffff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7;
    final progressPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 7;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant LoadingRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key, required this.store});
  final FinanceStore store;

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  ThemeMode get themeMode {
    if (widget.store.themeMode == 'light') return ThemeMode.light;
    if (widget.store.themeMode == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ManotyLOG',
    locale: const Locale('en', 'US'),
    themeMode: themeMode,
    theme: _buildTheme(Brightness.light),
    darkTheme: _buildTheme(Brightness.dark),
    home: AppShell(
      store: widget.store,
      onThemeModeChanged: () => setState(() {}),
    ),
  );

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff503c74),
        brightness: brightness,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor:
          dark ? const Color(0xff121018) : const Color(0xfff5f7fb),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff503c74),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xff211d29) : const Color(0xffffffff),
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xff2a2433) : const Color(0xfff9fafc),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        labelStyle: TextStyle(
          color: dark ? const Color(0xffd8cce5) : const Color(0xff55505d),
        ),
        hintStyle: TextStyle(
          color: dark ? const Color(0xffb9aeca) : const Color(0xff77727e),
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: dark ? const Color(0xff75677f) : const Color(0xffb5afbd),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: dark ? const Color(0xff75677f) : const Color(0xffb5afbd),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: const BorderSide(color: Color(0xffc9a4f5), width: 2),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xff2a2433) : Colors.white,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xff2a2630) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xff211d29) : Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xff503c74),
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xff503c74),
        indicatorColor: const Color(0xff6f5a92),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: Colors.white),
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: Colors.white),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.store,
    required this.onThemeModeChanged,
  });
  final FinanceStore store;
  final VoidCallback onThemeModeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
  String get title =>
      ['Overview', 'Transactions', 'Financial Plan', 'Settings'][tab];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder:
        (context, _) => Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            titleSpacing: 12,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/logo_transparent.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Text('$title'),
              ],
            ),
          ),
          body: IndexedStack(
            index: tab,
            children: [
              DashboardPage(store: widget.store),
              EntriesPage(store: widget.store),
              PlansPage(store: widget.store),
              SettingsPage(
                store: widget.store,
                onThemeModeChanged: widget.onThemeModeChanged,
              ),
            ],
          ),
          floatingActionButton:
              tab == 0 || tab == 1
                  ? FloatingActionButton(
                    shape: const CircleBorder(
                      side: BorderSide(color: Colors.white, width: 2),
                    ),
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEntryPage(store: widget.store),
                          ),
                        ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  )
                  : null,
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBar(
                height: 76,
                selectedIndex: tab,
                onDestinationSelected: (value) => setState(() => tab = value),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Overview',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'Transactions',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.track_changes_outlined),
                    selectedIcon: Icon(Icons.track_changes),
                    label: 'Plan',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
  );
}

enum DashboardPeriod { week, month, year }

enum DashboardFilter { all, income, expense }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.store});
  final FinanceStore store;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardPeriod period = DashboardPeriod.month;
  DashboardFilter filter = DashboardFilter.all;
  DateTime anchor = DateTime.now();

  ({DateTime start, DateTime end}) get range {
    if (period == DashboardPeriod.week) {
      final start = DateTime(
        anchor.year,
        anchor.month,
        anchor.day - anchor.weekday + 1,
      );
      return (start: start, end: start.add(const Duration(days: 7)));
    }
    if (period == DashboardPeriod.year) {
      final start = DateTime(anchor.year);
      return (start: start, end: DateTime(anchor.year + 1));
    }
    final start = DateTime(anchor.year, anchor.month);
    return (start: start, end: DateTime(anchor.year, anchor.month + 1));
  }

  void move(int amount) {
    if (period == DashboardPeriod.week)
      anchor = anchor.add(Duration(days: amount * 7));
    if (period == DashboardPeriod.month)
      anchor = DateTime(anchor.year, anchor.month + amount);
    if (period == DashboardPeriod.year)
      anchor = DateTime(anchor.year + amount, anchor.month);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentRange = range;
    final entries = widget.store.inRange(
      currentRange.start,
      currentRange.end,
      type:
          filter == DashboardFilter.all
              ? null
              : filter == DashboardFilter.income
              ? EntryType.income
              : EntryType.expense,
    )..sort((a, b) => b.date.compareTo(a.date));
    final income = widget.store.total(
      currentRange.start,
      currentRange.end,
      EntryType.income,
    );
    final expense = widget.store.total(
      currentRange.start,
      currentRange.end,
      EntryType.expense,
    );
    final net = income - expense;
    final selectedTotal =
        filter == DashboardFilter.income
            ? income
            : filter == DashboardFilter.expense
            ? expense
            : net;
    final selectedLabel =
        filter == DashboardFilter.income
            ? 'Selected income'
            : filter == DashboardFilter.expense
            ? 'Selected expenses'
            : 'Net balance';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        PeriodPicker(
          period: period,
          label: periodLabel(period, currentRange),
          onPrevious: () => move(-1),
          onNext: () => move(1),
        ),
        const SizedBox(height: 10),
        Text(
          'Filter | ${period == EntryPeriod.year ? '${anchor.year}' : monthLabel(anchor)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<DashboardPeriod>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Period'),
                items: const [
                  DropdownMenuItem(
                    value: DashboardPeriod.week,
                    child: Text('Week'),
                  ),
                  DropdownMenuItem(
                    value: DashboardPeriod.month,
                    child: Text('Month'),
                  ),
                  DropdownMenuItem(
                    value: DashboardPeriod.year,
                    child: Text('Year'),
                  ),
                ],
                onChanged:
                    (value) => setState(() {
                      period = value!;
                    }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<DashboardFilter>(
                initialValue: filter,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: DashboardFilter.all,
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: DashboardFilter.income,
                    child: Text('Income'),
                  ),
                  DropdownMenuItem(
                    value: DashboardFilter.expense,
                    child: Text('Expense'),
                  ),
                ],
                onChanged:
                    (value) => setState(() {
                      filter = value!;
                    }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                label: 'Income',
                value: income,
                color: Colors.green,
                icon: Icons.arrow_downward,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SummaryCard(
                label: 'Expenses',
                value: expense,
                color: Colors.red,
                icon: Icons.arrow_upward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: Icon(
              net >= 0 ? Icons.check_circle : Icons.warning_amber,
              color: net >= 0 ? Colors.green : Colors.red,
            ),
            title: Text(selectedLabel),
            subtitle: Text('${entries.length}'),
            trailing: Text(
              formatMoney(selectedTotal),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: net >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SectionTitle(title: 'Category summary'),
        CategoryBarSummary(
          title: 'Income',
          entries: entries.where((e) => e.type == EntryType.income).toList(),
          color: Colors.green,
        ),
        CategoryBarSummary(
          title: 'Expenses',
          entries: entries.where((e) => e.type == EntryType.expense).toList(),
          color: Colors.red,
        ),
        const SizedBox(height: 10),
        const SectionTitle(title: 'Recent transactions'),
        if (entries.isEmpty)
          const EmptyState(text: 'No transactions in this period')
        else
          ...entries.take(8).map((entry) => EntryTile(entry: entry)),
      ],
    );
  }
}

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key, required this.store});
  final FinanceStore store;

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

enum EntryPeriod { year, month, day }

enum EntryGrouping { week, day }

class _EntriesPageState extends State<EntriesPage> {
  EntryPeriod period = EntryPeriod.month;
  EntryGrouping grouping = EntryGrouping.day;
  EntryType? type;
  DateTime anchor = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final start =
        period == EntryPeriod.year
            ? DateTime(anchor.year)
            : period == EntryPeriod.day
            ? DateTime(anchor.year, anchor.month, anchor.day)
            : DateTime(anchor.year, anchor.month);
    final end =
        period == EntryPeriod.year
            ? DateTime(anchor.year + 1)
            : period == EntryPeriod.day
            ? start.add(const Duration(days: 1))
            : DateTime(anchor.year, anchor.month + 1);
    final entries = store.inRange(start, end, type: type)
      ..sort((a, b) => b.date.compareTo(a.date));
    final groups = <String, List<FinanceEntry>>{};
    for (final e in entries) {
      final key =
          period == EntryPeriod.day
              ? '${e.date.hour < 6
                  ? '1 AM - 6 AM'
                  : e.date.hour < 12
                  ? '6 AM - 12 PM'
                  : e.date.hour < 18
                  ? '1 PM - 6 PM'
                  : '6 PM - 12 AM'} · ${dateLabel(e.date)}'
              : grouping == EntryGrouping.week
              ? '${monthLabel(e.date)} - Week ${((e.date.day - 1) ~/ 7) + 1}'
              : dateLabel(e.date);
      groups.putIfAbsent(key, () => []).add(e);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<EntryPeriod>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Period'),
                items: const [
                  DropdownMenuItem(
                    value: EntryPeriod.year,
                    child: Text('Year'),
                  ),
                  DropdownMenuItem(
                    value: EntryPeriod.month,
                    child: Text('Month'),
                  ),
                  DropdownMenuItem(value: EntryPeriod.day, child: Text('Day')),
                ],
                onChanged: (v) => setState(() => period = v!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<EntryType?>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(
                    value: EntryType.income,
                    child: Text('Income'),
                  ),
                  DropdownMenuItem(
                    value: EntryType.expense,
                    child: Text('Expense'),
                  ),
                ],
                onChanged: (v) => setState(() => type = v),
              ),
            ),
          ],
        ),
        if (period == EntryPeriod.month) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<EntryGrouping>(
            isExpanded: true,
            initialValue: grouping,
            decoration: const InputDecoration(labelText: 'Group by'),
            items: const [
              DropdownMenuItem(value: EntryGrouping.week, child: Text('Week')),
              DropdownMenuItem(value: EntryGrouping.day, child: Text('Day')),
            ],
            onChanged: (v) => setState(() => grouping = v!),
          ),
        ],
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const EmptyState(text: 'No transactions in this period')
        else
          ...groups.entries.map(
            (group) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(title: group.key),
                ...group.value.map(
                  (entry) => Dismissible(
                    key: ValueKey(entry.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffa51d35),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss:
                        (_) => confirmTextDelete(context, entry.category),
                    onDismissed: (_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) store.removeEntry(entry.id);
                      });
                    },
                    child: EntryTile(entry: entry, store: store),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class PlansPage extends StatelessWidget {
  const PlansPage({super.key, required this.store});
  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final active = store.debts.where((debt) => !debt.isPaidOff).toList();
    final archived = store.debts.where((debt) => debt.isPaidOff).toList();
    final essential = store.essentialBudget;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        const SectionTitle(title: 'Emergency fund'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current savings  ${formatMoney(store.currentSavings)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('Planned expenses ${formatMoney(essential)}/month'),
                const SizedBox(height: 12),
                ReserveRow(
                  label: 'Starter buffer',
                  target: 10000,
                  current: store.currentSavings,
                ),
                ReserveRow(
                  label: '6-month reserve',
                  target: essential * 6,
                  current: store.currentSavings,
                ),
                ReserveRow(
                  label: '12-month reserve',
                  target: essential * 12,
                  current: store.currentSavings,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle(title: 'Active debts'),
            FilledButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddDebtPage(store: store),
                    ),
                  ),
              icon: const Icon(Icons.add),
              label: const Text('Add debt'),
            ),
          ],
        ),
        if (active.isEmpty)
          const EmptyState(text: 'No active debts')
        else
          ...active.map((debt) => DebtTile(debt: debt, store: store)),
        const SizedBox(height: 12),
        const SectionTitle(title: 'Paid-off debts'),
        if (archived.isEmpty)
          const EmptyState(text: 'No paid-off debts')
        else
          ...archived.map(
            (debt) => DebtTile(debt: debt, store: store, archived: true),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle(title: 'Budgets'),
            FilledButton.icon(
              onPressed: () => editBudget(context),
              icon: const Icon(Icons.add),
              label: const Text('Add budget'),
            ),
          ],
        ),
        if (store.budgets.isEmpty)
          const EmptyState(text: 'No budgets yet')
        else
          ...store.budgets.entries.map(
            (item) => Card(
              child: ListTile(
                onTap: () => editBudget(context, item),
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(item.key),
                subtitle: Text('${formatMoney(item.value)} / month'),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') {
                      editBudget(context, item);
                    } else {
                      deleteBudget(context, item.key);
                    }
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> editBudget(
    BuildContext context, [
    MapEntry<String, double>? existing,
  ]) async {
    final result = await showDialog<BudgetDraft>(
      context: context,
      builder: (_) => BudgetEditorDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;
    final duplicate =
        store.budgets.containsKey(result.name) && existing?.key != result.name;
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A budget with this name already exists')),
      );
      return;
    }
    await store.saveBudget(
      previousName: existing?.key,
      name: result.name,
      amount: result.amount,
    );
  }

  Future<void> deleteBudget(BuildContext context, String name) async {
    final confirmed = await confirmAction(
      context,
      'Delete the "$name" budget?',
    );
    if (confirmed) await store.removeBudget(name);
  }
}

class BudgetDraft {
  const BudgetDraft({required this.name, required this.amount});
  final String name;
  final double amount;
}

class BudgetEditorDialog extends StatefulWidget {
  const BudgetEditorDialog({super.key, this.existing});
  final MapEntry<String, double>? existing;

  @override
  State<BudgetEditorDialog> createState() => _BudgetEditorDialogState();
}

class _BudgetEditorDialogState extends State<BudgetEditorDialog> {
  late final TextEditingController nameController;
  late final TextEditingController amountController;
  String? error;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.existing?.key ?? '');
    amountController = TextEditingController(
      text: widget.existing?.value.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add budget' : 'Edit budget'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Budget name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monthly amount (THB)',
            errorText: error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Save')),
    ],
  );

  void submit() {
    final name = nameController.text.trim();
    final amount = double.tryParse(amountController.text.replaceAll(',', ''));
    if (name.isEmpty || amount == null || amount < 0) {
      setState(() => error = 'Enter a valid name and amount');
      return;
    }
    Navigator.pop(context, BudgetDraft(name: name, amount: amount));
  }
}

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
      const SectionTitle(title: 'Local data'),
      const Card(
        child: ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Offline mode'),
          subtitle: Text(
            'Your data stays on this device and is never uploaded',
          ),
        ),
      ),
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
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Card(
        child: ListTile(
          leading: Icon(Icons.phone_android),
          title: Text('Version 0.2'),
          subtitle: Text(
            'Dashboard filters, backups, debt details, and receipt attachments',
          ),
        ),
      ),
    ],
  );
}

class AddEntryPage extends StatefulWidget {
  const AddEntryPage({super.key, required this.store});
  final FinanceStore store;

  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  EntryType type = EntryType.expense;
  String? category;
  DateTime date = DateTime.now();
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    category = widget.store.defaultExpenseCategory;
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        type == EntryType.expense
            ? widget.store.expenseCategories
            : widget.store.incomeCategories;
    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: EntryType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {type},
              onSelectionChanged:
                  (value) => setState(() {
                    type = value.first;
                    final next =
                        type == EntryType.expense
                            ? widget.store.expenseCategories
                            : widget.store.incomeCategories;
                    final preferred =
                        type == EntryType.expense
                            ? widget.store.defaultExpenseCategory
                            : widget.store.defaultIncomeCategory;
                    category =
                        next.contains(preferred)
                            ? preferred
                            : (next.contains(category) ? category : null);
                  }),
            ),
            const SizedBox(height: 14),
            CategorySelector(
              categories: categories,
              selected: category,
              onSelected: (value) => setState(() => category = value),
              onAdd: addCategory,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (THB)',
                prefixText: '฿ ',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text('Date · ${dateLabel(date)}'),
              subtitle: Text('Time · ${timeLabel(date)}'),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDate: date,
                  );
                  if (picked != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(date),
                    );
                    setState(() {
                      date = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        time?.hour ?? date.hour,
                        time?.minute ?? date.minute,
                      );
                    });
                  }
                },
                child: const Text('Change'),
              ),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check),
              label: const Text('Save transaction'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> save() async {
    final amount = double.tryParse(amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (category == null || category!.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select or add a category')));
      return;
    }
    await widget.store.addEntry(
      FinanceEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: date,
        type: type,
        category: category ?? '',
        amount: amount,
        note: noteController.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> addCategory() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Add category'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Category name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Add'),
              ),
            ],
          ),
    );
    if (value == null || value.trim().isEmpty) return;
    final normalized = value.trim();
    if (mounted) setState(() => category = normalized);
    await widget.store.addCategory(type, normalized);
  }
}

enum DebtCalculationMode { balance, payment }

class AddDebtPage extends StatefulWidget {
  const AddDebtPage({super.key, required this.store});
  final FinanceStore store;

  @override
  State<AddDebtPage> createState() => _AddDebtPageState();
}

class _AddDebtPageState extends State<AddDebtPage> {
  DebtCalculationMode calculationMode = DebtCalculationMode.balance;
  final name = TextEditingController();
  final balance = TextEditingController();
  final dueDay = TextEditingController(text: '1');
  final note = TextEditingController();
  DateTime start = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime end = DateTime(DateTime.now().year, DateTime.now().month + 11);

  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    dueDay.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add debt')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Debt name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: balance,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText:
                  calculationMode == DebtCalculationMode.balance
                      ? 'Initial balance'
                      : 'Monthly payment',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<DebtCalculationMode>(
            segments: const [
              ButtonSegment(
                value: DebtCalculationMode.balance,
                label: Text('Balance ÷ months'),
              ),
              ButtonSegment(
                value: DebtCalculationMode.payment,
                label: Text('Payment × months'),
              ),
            ],
            selected: {calculationMode},
            onSelectionChanged:
                (value) => setState(() => calculationMode = value.first),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Start month · ${monthLabel(start)}'),
            trailing: TextButton(
              onPressed: chooseStart,
              child: const Text('Choose month'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('End month · ${monthLabel(end)}'),
            trailing: TextButton(
              onPressed: chooseEnd,
              child: const Text('Choose month'),
            ),
          ),
          Text(
            'Total ${monthsBetweenInclusive(start, end)} months · '
            '${calculationMode == DebtCalculationMode.balance ? 'Monthly payment' : 'Initial balance'} '
            '${formatMoney(calculatedSecondaryValue)}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dueDay,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Pay every day of month (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save),
            label: const Text('Save debt'),
          ),
        ],
      ),
    ),
  );

  Future<void> chooseStart() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: start,
    );
    if (picked != null) {
      setState(() {
        start = DateTime(picked.year, picked.month);
        if (end.isBefore(start)) end = start;
      });
    }
  }

  Future<void> chooseEnd() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: end.isBefore(start) ? start : end,
    );
    if (picked != null) {
      setState(() => end = DateTime(picked.year, picked.month));
    }
  }

  int get totalMonths => monthsBetweenInclusive(start, end);

  double get calculatedSecondaryValue {
    final value = double.tryParse(balance.text.replaceAll(',', '')) ?? 0;
    if (calculationMode == DebtCalculationMode.balance) {
      return totalMonths == 0 ? 0 : value / totalMonths;
    }
    return value * totalMonths;
  }

  Future<void> save() async {
    final enteredValue = double.tryParse(balance.text.replaceAll(',', '')) ?? 0;
    final monthsCount = totalMonths;
    final debt = Debt(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text.trim(),
      initialBalance:
          calculationMode == DebtCalculationMode.balance
              ? enteredValue
              : enteredValue * monthsCount,
      installment:
          calculationMode == DebtCalculationMode.balance
              ? (monthsCount == 0 ? 0 : enteredValue / monthsCount)
              : enteredValue,
      startMonth: monthKey(start),
      totalMonths: monthsCount,
      dueDay: int.tryParse(dueDay.text) ?? 1,
      note: note.text.trim(),
    );
    if (debt.name.isEmpty || debt.initialBalance <= 0 || monthsCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a debt name and balance')),
      );
      return;
    }
    await widget.store.addDebt(debt);
    if (mounted) Navigator.pop(context);
  }
}

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

  Future<void> confirm() async {
    final value = double.tryParse(amount.text.replaceAll(',', ''));
    if (value == null || value <= 0) return;
    await widget.store.markDebtPayment(
      debt: widget.debt,
      month: widget.month,
      amount: value,
      receiptNumber: receipt.text.trim(),
      receiptFileName: receiptFileName,
    );
    if (mounted) Navigator.pop(context);
  }
}

class DebtTile extends StatelessWidget {
  const DebtTile({
    super.key,
    required this.debt,
    required this.store,
    this.archived = false,
  });
  final Debt debt;
  final FinanceStore store;
  final bool archived;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DebtDetailPage(store: store, debt: debt),
            ),
          ),
      leading: Icon(archived ? Icons.inventory_2_outlined : Icons.receipt_long),
      title: Text(debt.name),
      subtitle: Text(
        debt.totalMonths == 0
            ? 'No payment schedule'
            : '${debt.payments.length}/${debt.totalMonths} months · ${formatMoney(debt.remainingBalance)} remaining',
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class CategoryBarSummary extends StatelessWidget {
  const CategoryBarSummary({
    super.key,
    required this.title,
    required this.entries,
    required this.color,
  });
  final String title;
  final List<FinanceEntry> entries;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final items = categorySummary(entries).take(3).toList();
    final max = items.isEmpty ? 1.0 : items.first.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (items.isEmpty)
              const Text('No data')
            else
              ...items.asMap().entries.map(
                (x) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          '${x.key + 1}. ${x.value.key}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: x.value.value / max,
                          color:
                              [Colors.pink, Colors.orange, Colors.amber][x.key],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(formatMoney(x.value.value)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CategoryManager extends StatelessWidget {
  const CategoryManager({super.key, required this.store});
  final FinanceStore store;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        categorySection(
          context,
          EntryType.income,
          'Income',
          store.incomeCategories,
          store.defaultIncomeCategory,
        ),
        categorySection(
          context,
          EntryType.expense,
          'Expense',
          store.expenseCategories,
          store.defaultExpenseCategory,
        ),
      ],
    ),
  );
  Widget categorySection(
    BuildContext context,
    EntryType type,
    String title,
    List<String> items,
    String? defaultName,
  ) {
    return ExpansionTile(
      title: Text(title),
      children:
          items.map((name) {
            return ListTile(
              title: Text(name),
              leading: Icon(
                name == defaultName ? Icons.star : Icons.label_outline,
              ),
              onTap: () async {
                final controller = TextEditingController(text: name);
                final value = await showDialog<String>(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: const Text('Rename category'),
                        content: TextField(controller: controller),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed:
                                () => Navigator.pop(context, controller.text),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                );
                controller.dispose();
                if (value != null)
                  await store.renameCategory(type, name, value);
              },
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Set default',
                    onPressed: () => store.setDefaultCategory(type, name),
                    icon: const Icon(Icons.star_border),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () async {
                      final ok = await store.deleteCategory(type, name);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cannot delete a category that has transactions',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.onAdd,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelected;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(4),
    onTap: () => _showOptions(context),
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Category',
        suffixIcon: Icon(Icons.arrow_drop_down),
      ),
      child: Text(selected ?? 'Select or add a category'),
    ),
  );

  Future<void> _showOptions(BuildContext context) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Choose a category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...categories.map(
                  (item) => ListTile(
                    leading: Icon(
                      item == selected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                    ),
                    title: Text(item),
                    onTap: () => Navigator.pop(sheetContext, item),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add new category'),
                  onTap: () => Navigator.pop(sheetContext, '__add__'),
                ),
              ],
            ),
          ),
    );
    if (!context.mounted || value == null) return;
    if (value == '__add__') {
      await onAdd();
    } else {
      onSelected(value);
    }
  }
}

class PeriodPicker extends StatelessWidget {
  const PeriodPicker({
    super.key,
    required this.period,
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });
  final DashboardPeriod period;
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Card(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    ),
  );
}

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

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, this.store});
  final FinanceEntry entry;
  final FinanceStore? store;
  @override
  Widget build(BuildContext context) {
    final income = entry.type == EntryType.income;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: store == null ? null : () => showEntryActions(context, store!),
        leading: CircleAvatar(
          backgroundColor: income ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            income ? Icons.add : Icons.remove,
            color: income ? Colors.green : Colors.red,
          ),
        ),
        title: Text(entry.category),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel(entry.date)),
            if (entry.note.isNotEmpty) Text(entry.note),
          ],
        ),
        trailing: Text(
          '${income ? '+' : '-'}${formatMoney(entry.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: income ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ),
    );
  }

  Future<void> showEntryActions(
    BuildContext context,
    FinanceStore store,
  ) async {
    final canSwitch = DateTime.now().difference(entry.date).inHours <= 72;
    final targetType =
        entry.type == EntryType.income ? EntryType.expense : EntryType.income;
    final categories =
        targetType == EntryType.income
            ? store.incomeCategories
            : store.expenseCategories;
    final category = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Move to category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...categories.map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(c),
                      onTap: () => Navigator.pop(sheetContext, c),
                    ),
                  ),
                  if (canSwitch)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Switch to ${targetType.name}'),
                      leading: const Icon(Icons.swap_horiz),
                      onTap: () => Navigator.pop(sheetContext, '__switch__'),
                    ),
                ],
              ),
            ),
          ),
    );
    if (category == null) return;
    final type = category == '__switch__' ? targetType : entry.type;
    final name =
        category == '__switch__'
            ? (type == EntryType.income
                ? store.defaultIncomeCategory
                : store.defaultExpenseCategory)
            : category;
    if (name == null) return;
    await store.updateEntry(
      FinanceEntry(
        id: entry.id,
        date: entry.date,
        type: type,
        category: name,
        amount: entry.amount,
        note: entry.note,
        sourceDebtId: entry.sourceDebtId,
        sourceDebtMonth: entry.sourceDebtMonth,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(text)),
    ),
  );
}

List<MapEntry<String, double>> categorySummary(List<FinanceEntry> entries) {
  final result = <String, double>{};
  for (final entry in entries) {
    result[entry.category] = (result[entry.category] ?? 0) + entry.amount;
  }
  return result.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

String formatMoney(double value) => '${value.toStringAsFixed(0)} $currency';
String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

int monthsBetweenInclusive(DateTime start, DateTime end) {
  if (end.isBefore(start)) return 0;
  return (end.year - start.year) * 12 + end.month - start.month + 1;
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _shortMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String monthLabel(DateTime month) {
  return '${_monthNames[month.month - 1]}, ${month.year}';
}

String dateLabel(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

String timeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

String periodLabel(
  DashboardPeriod period,
  ({DateTime start, DateTime end}) range,
) {
  if (period == DashboardPeriod.month) return monthLabel(range.start);
  if (period == DashboardPeriod.year) return '${range.start.year}';
  final end = range.end.subtract(const Duration(days: 1));
  if (range.start.year != end.year) {
    return '${range.start.day} ${_shortMonthNames[range.start.month - 1]} ${range.start.year} - '
        '${end.day} ${_shortMonthNames[end.month - 1]} ${end.year}';
  }
  return '${range.start.day} ${_shortMonthNames[range.start.month - 1]} - '
      '${end.day} ${_shortMonthNames[end.month - 1]} ${end.year}';
}

Future<bool> confirmAction(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Confirm'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
    ) ??
    false;

Future<bool> confirmTextDelete(BuildContext context, String name) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder:
        (_) => AlertDialog(
          title: Text('Delete "$name"?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Type confirm to continue',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.pop(
                    context,
                    controller.text.trim().toLowerCase() == 'confirm',
                  ),
              child: const Text('Delete'),
            ),
          ],
        ),
  );
  controller.dispose();
  return result == true;
}
