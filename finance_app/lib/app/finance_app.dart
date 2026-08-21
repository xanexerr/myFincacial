part of finance_app;

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
                  borderRadius: BorderRadius.circular(AppRadius.lg),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
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
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          borderSide: BorderSide(
            color: dark ? const Color(0xff75677f) : const Color(0xffb5afbd),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          borderSide: BorderSide(
            color: dark ? const Color(0xff75677f) : const Color(0xffb5afbd),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          borderSide: const BorderSide(color: Color(0xffc9a4f5), width: 2),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(
          fontSize: 16,
          color: dark ? Colors.white : const Color(0xff211d29),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xff2a2433) : Colors.white,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xff2a2630) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: dark ? Colors.white : const Color(0xff211d29),
        ),
        contentTextStyle: TextStyle(
          fontSize: 16,
          color: dark ? Colors.white : const Color(0xff211d29),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        textStyle: TextStyle(
          fontSize: 16,
          color: dark ? Colors.white : const Color(0xff211d29),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
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
  late final PageController _pageController;
  final entriesPageKey = GlobalKey<_EntriesPageState>();
  String get title =>
      ['Overview', 'Transactions', 'Financial Plan', 'Settings'][tab];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder:
        (context, _) => Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.lg),
              ),
            ),
            titleSpacing: 12,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
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
          body: PageView(
            controller: _pageController,
            onPageChanged: (value) => setState(() => tab = value),
            physics: const BouncingScrollPhysics(),
            children: [
                DashboardPage(store: widget.store),
                EntriesPage(key: entriesPageKey, store: widget.store),
                PlansPage(store: widget.store),
                SettingsPage(
                  store: widget.store,
                  onThemeModeChanged: widget.onThemeModeChanged,
                ),
            ],
          ),
          floatingActionButton:
              tab == 1
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'transaction-filter',
                        backgroundColor: const Color(0xffffb800),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        onPressed:
                            () =>
                                entriesPageKey.currentState?._showFilterPopup(),
                        child: const Icon(Icons.filter_alt),
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        heroTag: 'transaction-add',
                        backgroundColor: const Color(0xff3f4146),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        onPressed:
                            () => showAddEntryDialog(context, widget.store),
                        child: const Icon(Icons.add, size: 28),
                      ),
                    ],
                  )
                  : tab == 0
                  ? FloatingActionButton(
                    heroTag: 'overview-add',
                    backgroundColor: const Color(0xff3f4146),
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    onPressed: () => showAddEntryDialog(context, widget.store),
                    child: const Icon(Icons.add, size: 30),
                  )
                  : null,
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              child: NavigationBar(
                height: 80,
                selectedIndex: tab,
                onDestinationSelected: (value) {
                  _pageController.animateToPage(
                    value,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                  );
                },
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
