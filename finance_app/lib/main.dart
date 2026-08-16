import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const currency = 'THB';
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
  });

  final String id;
  final DateTime date;
  final EntryType type;
  final String category;
  final double amount;
  final String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'type': type.name,
    'category': category,
    'amount': amount,
    'note': note,
  };

  factory FinanceEntry.fromJson(Map<String, dynamic> json) => FinanceEntry(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    type: json['type'] == 'income' ? EntryType.income : EntryType.expense,
    category: migrateCategoryName(json['category'] as String),
    amount: (json['amount'] as num).toDouble(),
    note: (json['note'] as String?) ?? '',
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
    entries.removeWhere((entry) => entry.id == id);
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
    debt.payments.removeWhere((payment) => payment.monthKey == month);
    debt.payments.add(
      DebtPayment(
        monthKey: month,
        amount: amount,
        paidAt: DateTime.now(),
        receiptNumber: receiptNumber,
        receiptFileName: receiptFileName,
      ),
    );
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
  final store = FinanceStore();
  await store.load();
  runApp(FinanceApp(store: store));
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key, required this.store});
  final FinanceStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Xan Finance',
    locale: const Locale('en', 'US'),
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b87)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff7fafb),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: AppShell(store: store),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final FinanceStore store;

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
          appBar: AppBar(title: Text('$title')),
          body: IndexedStack(
            index: tab,
            children: [
              DashboardPage(store: widget.store),
              EntriesPage(store: widget.store),
              PlansPage(store: widget.store),
              SettingsPage(store: widget.store),
            ],
          ),
          floatingActionButton:
              tab == 0 || tab == 1
                  ? FloatingActionButton.extended(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEntryPage(store: widget.store),
                          ),
                        ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add transaction'),
                  )
                  : null,
          bottomNavigationBar: NavigationBar(
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
            subtitle: Text('${entries.length} transactions'),
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
        ...categorySummary(entries).map(
          (item) => BudgetProgress(
            label: item.key,
            actual: item.value,
            budget: widget.store.budgets[item.key] ?? item.value,
          ),
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

class EntriesPage extends StatelessWidget {
  const EntriesPage({super.key, required this.store});
  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final entries = store.inRange(
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    )..sort((a, b) => b.date.compareTo(a.date));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text(
          'Transactions · ${monthLabel(now)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const EmptyState(text: 'No transactions this month')
        else
          ...entries.map(
            (entry) => Dismissible(
              key: ValueKey(entry.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red.shade100,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete),
              ),
              onDismissed: (_) => store.removeEntry(entry.id),
              child: EntryTile(entry: entry),
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
        const SizedBox(height: 12),
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
  const SettingsPage({super.key, required this.store});
  final FinanceStore store;

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
                    category = next.contains(category) ? category : null;
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
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDate: date,
                  );
                  if (picked != null) setState(() => date = picked);
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

class AddDebtPage extends StatefulWidget {
  const AddDebtPage({super.key, required this.store});
  final FinanceStore store;

  @override
  State<AddDebtPage> createState() => _AddDebtPageState();
}

class _AddDebtPageState extends State<AddDebtPage> {
  final name = TextEditingController();
  final balance = TextEditingController();
  final installment = TextEditingController();
  final months = TextEditingController();
  final dueDay = TextEditingController(text: '1');
  final note = TextEditingController();
  DateTime start = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    installment.dispose();
    months.dispose();
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
            decoration: const InputDecoration(labelText: 'Initial balance'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: installment,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monthly payment'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: months,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total months'),
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
          TextField(
            controller: dueDay,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Due day (optional)'),
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
    if (picked != null)
      setState(() => start = DateTime(picked.year, picked.month));
  }

  Future<void> save() async {
    final debt = Debt(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text.trim(),
      initialBalance: double.tryParse(balance.text) ?? 0,
      installment: double.tryParse(installment.text) ?? 0,
      startMonth: monthKey(start),
      totalMonths: int.tryParse(months.text) ?? 0,
      dueDay: int.tryParse(dueDay.text) ?? 1,
      note: note.text.trim(),
    );
    if (debt.name.isEmpty || debt.initialBalance <= 0) {
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
  const EntryTile({super.key, required this.entry});
  final FinanceEntry entry;
  @override
  Widget build(BuildContext context) {
    final income = entry.type == EntryType.income;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: income ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            income ? Icons.add : Icons.remove,
            color: income ? Colors.green : Colors.red,
          ),
        ),
        title: Text(entry.category),
        subtitle: Text(
          '${dateLabel(entry.date)}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
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
