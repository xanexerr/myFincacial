import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const currency = 'บาท';
const filesChannel = MethodChannel('com.xan.personal_finance/files');

const expenseCategories = <String>[
  'ค่าเช่า',
  'ค่าน้ำไฟ+เน็ต',
  'ค่าอาหาร',
  'ค่าน้ำมัน',
  'โทรศัพท์',
  'ผ่อนมือถือ',
  'ผ่อนกีตาร์',
  'ท่องเที่ยว',
  'ซ่อมรถ',
  'Codex (จ่ายเอง)',
  'YouTube Music',
  'ค่าเทอมที่จ่ายเอง',
  'อื่น ๆ',
];
const incomeCategories = <String>['เงินจากพ่อ', 'รายรับอื่น'];
const defaultBudgets = <String, double>{
  'ค่าเช่า': 0,
  'ค่าน้ำไฟ+เน็ต': 0,
  'ค่าอาหาร': 0,
  'ค่าน้ำมัน': 0,
  'โทรศัพท์': 0,
  'ผ่อนมือถือ': 0,
  'ผ่อนกีตาร์': 0,
  'ท่องเที่ยว': 0,
  'ซ่อมรถ': 0,
  'Codex (จ่ายเอง)': 0,
  'YouTube Music': 0,
  'ค่าเทอมที่จ่ายเอง': 0,
  'อื่น ๆ': 0,
};
const essentialCategories = <String>{
  'ค่าเช่า',
  'ค่าน้ำไฟ+เน็ต',
  'ค่าอาหาร',
  'ค่าน้ำมัน',
  'โทรศัพท์',
  'ผ่อนมือถือ',
  'ผ่อนกีตาร์',
  'ซ่อมรถ',
};

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
    category: json['category'] as String,
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
  Map<String, double> budgets = Map<String, double>.from(defaultBudgets);
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
        budgets = savedBudgets.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
      }
      currentSavings = (data['currentSavings'] as num?)?.toDouble() ?? 0;
    } catch (_) {
      if (debts.isEmpty) debts.addAll(defaultDebts());
    }
  }

  Map<String, dynamic> snapshot() => {
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'debts': debts.map((debt) => debt.toJson()).toList(),
    'budgets': budgets,
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
      budgets = ((data['budgets'] as Map<String, dynamic>?) ?? defaultBudgets)
          .map((key, value) => MapEntry(key, (value as num).toDouble()));
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
  double get essentialBudget => budgets.entries
      .where((entry) => essentialCategories.contains(entry.key))
      .fold(0, (sum, entry) => sum + entry.value);
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
  String get title => ['ภาพรวม', 'รายการ', 'แผนการเงิน', 'ตั้งค่า'][tab];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder:
        (context, _) => Scaffold(
          appBar: AppBar(title: Text('Xan Finance · $title')),
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
                    label: const Text('เพิ่มรายการ'),
                  )
                  : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (value) => setState(() => tab = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'ภาพรวม',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'รายการ',
              ),
              NavigationDestination(
                icon: Icon(Icons.track_changes_outlined),
                selectedIcon: Icon(Icons.track_changes),
                label: 'แผน',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'ตั้งค่า',
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
            ? 'รายรับที่เลือก'
            : filter == DashboardFilter.expense
            ? 'รายจ่ายที่เลือก'
            : 'เงินเหลือ/ขาด';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        PeriodPicker(
          period: period,
          label: periodLabel(currentRange),
          onPrevious: () => move(-1),
          onNext: () => move(1),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<DashboardPeriod>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'ช่วงเวลา'),
                items: const [
                  DropdownMenuItem(
                    value: DashboardPeriod.week,
                    child: Text('สัปดาห์'),
                  ),
                  DropdownMenuItem(
                    value: DashboardPeriod.month,
                    child: Text('เดือน'),
                  ),
                  DropdownMenuItem(
                    value: DashboardPeriod.year,
                    child: Text('ปี'),
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
                decoration: const InputDecoration(labelText: 'ประเภท'),
                items: const [
                  DropdownMenuItem(
                    value: DashboardFilter.all,
                    child: Text('ทั้งหมด'),
                  ),
                  DropdownMenuItem(
                    value: DashboardFilter.income,
                    child: Text('รายรับ'),
                  ),
                  DropdownMenuItem(
                    value: DashboardFilter.expense,
                    child: Text('รายจ่าย'),
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
                label: 'รายรับ',
                value: income,
                color: Colors.green,
                icon: Icons.arrow_downward,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SummaryCard(
                label: 'รายจ่าย',
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
            subtitle: Text('${entries.length} รายการ'),
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
        const SectionTitle(title: 'สรุปตามหมวดหมู่'),
        ...categorySummary(entries).map(
          (item) => BudgetProgress(
            label: item.key,
            actual: item.value,
            budget: widget.store.budgets[item.key] ?? item.value,
          ),
        ),
        const SizedBox(height: 10),
        const SectionTitle(title: 'รายการล่าสุด'),
        if (entries.isEmpty)
          const EmptyState(text: 'ยังไม่มีรายการในช่วงนี้')
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
          'รายการเดือน ${monthLabel(now)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const EmptyState(text: 'ยังไม่มีรายการเดือนนี้')
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
        const SectionTitle(title: 'เงินสำรองฉุกเฉิน'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เงินเก็บปัจจุบัน  ${formatMoney(store.currentSavings)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('รายจ่ายจำเป็น ${formatMoney(essential)}/เดือน'),
                const SizedBox(height: 12),
                ReserveRow(
                  label: 'กันชนแรก',
                  target: 10000,
                  current: store.currentSavings,
                ),
                ReserveRow(
                  label: 'สำรอง 6 เดือน',
                  target: essential * 6,
                  current: store.currentSavings,
                ),
                ReserveRow(
                  label: 'สำรอง 12 เดือน',
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
            const SectionTitle(title: 'หนี้สินที่กำลังผ่อน'),
            FilledButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddDebtPage(store: store),
                    ),
                  ),
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มหนี้'),
            ),
          ],
        ),
        if (active.isEmpty)
          const EmptyState(text: 'ยังไม่มีหนี้ที่กำลังผ่อน')
        else
          ...active.map((debt) => DebtTile(debt: debt, store: store)),
        const SizedBox(height: 12),
        const SectionTitle(title: 'หนี้ที่จ่ายหมดแล้ว'),
        if (archived.isEmpty)
          const EmptyState(text: 'ยังไม่มีรายการที่จ่ายหมด')
        else
          ...archived.map(
            (debt) => DebtTile(debt: debt, store: store, archived: true),
          ),
        const SizedBox(height: 12),
        const SectionTitle(title: 'งบประมาณที่ตั้งไว้'),
        ...store.budgets.entries.map(
          (item) => ListTile(
            dense: true,
            title: Text(item.key),
            trailing: Text(formatMoney(item.value)),
          ),
        ),
      ],
    );
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
      const SectionTitle(title: 'ข้อมูลส่วนตัวในเครื่อง'),
      const Card(
        child: ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('โหมดออฟไลน์'),
          subtitle: Text('ข้อมูลเก็บไว้ในเครื่องนี้ ไม่ส่งขึ้นระบบออนไลน์'),
        ),
      ),
      const SizedBox(height: 12),
      const SectionTitle(title: 'เงินตั้งต้น'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: savingsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'เงินเก็บปัจจุบัน (บาท)',
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
                      const SnackBar(content: Text('บันทึกเงินเก็บแล้ว')),
                    );
                },
                icon: const Icon(Icons.save),
                label: const Text('บันทึก'),
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
              subtitle: const Text('ส่งออกข้อมูลและสลิปเป็นไฟล์ .xanbackup'),
              onTap: () async {
                final ok = await widget.store.exportBackup();
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'สำรองข้อมูลแล้ว'
                            : 'ยกเลิกหรือสำรองข้อมูลไม่สำเร็จ',
                      ),
                    ),
                  );
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Import Backup'),
              subtitle: const Text('นำข้อมูลจากไฟล์กลับเข้าแอป'),
              onTap: () async {
                final allow = await confirmAction(
                  context,
                  'นำเข้า Backup จะเขียนทับข้อมูลปัจจุบัน ยืนยันหรือไม่?',
                );
                if (!allow) return;
                final ok = await widget.store.importBackup();
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'กู้คืนข้อมูลแล้ว' : 'นำเข้าไม่สำเร็จ',
                      ),
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
          title: Text('เวอร์ชัน 0.2'),
          subtitle: Text(
            'Dashboard filter, backup, หนี้แบบละเอียด และการแนบสลิป',
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
  String category = expenseCategories.first;
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
        type == EntryType.expense ? expenseCategories : incomeCategories;
    if (!categories.contains(category)) category = categories.first;
    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มรายการ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text('รายจ่าย'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: EntryType.income,
                  label: Text('รายรับ'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {type},
              onSelectionChanged:
                  (value) => setState(() {
                    type = value.first;
                    category =
                        type == EntryType.expense
                            ? expenseCategories.first
                            : incomeCategories.first;
                  }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'หมวดหมู่'),
              items:
                  categories
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => category = value!),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'จำนวนเงิน (บาท)',
                prefixText: '฿ ',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text('วันที่ ${date.day}/${date.month}/${date.year}'),
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
                child: const Text('เปลี่ยน'),
              ),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ (ไม่บังคับ)',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check),
              label: const Text('บันทึกรายการ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> save() async {
    final amount = double.tryParse(amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาใส่จำนวนเงินให้ถูกต้อง')),
      );
      return;
    }
    await widget.store.addEntry(
      FinanceEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: date,
        type: type,
        category: category,
        amount: amount,
        note: noteController.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
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
    appBar: AppBar(title: const Text('เพิ่มหนี้')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'ชื่อหนี้'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: balance,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ยอดหนี้ตั้งต้น'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: installment,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ค่างวดต่อเดือน'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: months,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'จำนวนเดือนทั้งหมด'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('เริ่มเดือน ${monthLabel(start)}'),
            trailing: TextButton(
              onPressed: chooseStart,
              child: const Text('เลือกเดือน'),
            ),
          ),
          TextField(
            controller: dueDay,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'วันที่ครบกำหนด (ไม่บังคับ)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'หมายเหตุ'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save),
            label: const Text('บันทึกหนี้'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อและยอดหนี้')));
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
  Widget build(BuildContext context) {
    final months = debt.dueMonths();
    return Scaffold(
      appBar: AppBar(
        title: Text(debt.name),
        actions: [
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
                  Text('ยอดตั้งต้น ${formatMoney(debt.initialBalance)}'),
                  Text('จ่ายแล้ว ${formatMoney(debt.paidTotal)}'),
                  Text('คงเหลือประมาณ ${formatMoney(debt.remainingBalance)}'),
                  if (debt.note.isNotEmpty) Text(debt.note),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionTitle(title: 'ตารางชำระ'),
          if (months.isEmpty)
            const EmptyState(text: 'หนี้นี้ยังไม่ได้กำหนดจำนวนเดือน')
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
                        ? 'ยังไม่ยืนยันการจ่าย'
                        : 'จ่ายแล้ว ${formatMoney(payment.amount)}${payment.receiptNumber.isEmpty ? '' : ' · ${payment.receiptNumber}'}',
                  ),
                  trailing:
                      payment == null
                          ? FilledButton(
                            onPressed: () => showPayment(context, month),
                            child: const Text('จ่าย'),
                          )
                          : const Icon(Icons.done),
                ),
              );
            }),
        ],
      ),
    );
  }

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
          'ยืนยันการจ่าย ${monthLabel(DateTime.parse('${widget.month}-01'))}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'จำนวนที่จ่าย'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: receipt,
          decoration: const InputDecoration(labelText: 'เลขสลิป (ไม่บังคับ)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: pickImage,
          icon: const Icon(Icons.image_outlined),
          label: Text(
            receiptFileName == null
                ? 'แนบภาพสลิป (ไม่บังคับ)'
                : 'แนบแล้ว: $receiptFileName',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: confirm,
          icon: const Icon(Icons.check),
          label: const Text('Confirm การจ่าย'),
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
            ? 'ยังไม่กำหนดตารางชำระ'
            : '${debt.payments.length}/${debt.totalMonths} เดือน · เหลือ ${formatMoney(debt.remainingBalance)}',
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
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
          '${entry.date.day}/${entry.date.month}/${entry.date.year}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
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
String monthLabel(DateTime month) {
  const names = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  return '${names[month.month - 1]} ${month.year + 543}';
}

String periodLabel(({DateTime start, DateTime end}) range) =>
    '${range.start.day}/${range.start.month}/${range.start.year + 543} - ${range.end.subtract(const Duration(days: 1)).day}/${range.end.subtract(const Duration(days: 1)).month}/${range.end.year + 543}';

Future<bool> confirmAction(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('ยืนยัน'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ยืนยัน'),
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
          title: Text('คุณต้องการจะลบรายการ "$name" จริงหรือไม่'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'พิมพ์ confirm เพื่อยืนยัน',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.pop(
                    context,
                    controller.text.trim().toLowerCase() == 'confirm',
                  ),
              child: const Text('ลบ'),
            ),
          ],
        ),
  );
  controller.dispose();
  return result == true;
}
