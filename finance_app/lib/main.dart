library finance_app;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

part 'core/app_core.dart';
part 'domain/entities/finance_models.dart';
part 'state/finance_store.dart';
part 'app/finance_app.dart';
part 'presentation/dashboard/dashboard_page.dart';
part 'presentation/entries/entries_page.dart';
part 'presentation/plans/plans_page.dart';
part 'presentation/settings/settings_page.dart';
part 'presentation/entries/add_entry_page.dart';
part 'presentation/debts/add_debt_page.dart';
part 'presentation/debts/debt_detail_page.dart';
part 'presentation/debts/widgets/debt_tile.dart';
part 'presentation/dashboard/widgets/category_bar_summary.dart';
part 'presentation/settings/widgets/category_manager.dart';
part 'presentation/entries/widgets/category_selector.dart';
part 'presentation/dashboard/widgets/period_picker.dart';
part 'presentation/dashboard/widgets/summary_card.dart';
part 'presentation/plans/widgets/budget_progress.dart';
part 'presentation/plans/widgets/reserve_row.dart';
part 'presentation/entries/widgets/entry_tile.dart';
part 'presentation/shared/widgets/section_title.dart';
part 'presentation/shared/widgets/empty_state.dart';
part 'core/utils/finance_utils.dart';
part 'presentation/shared/dialogs/confirmation_dialogs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LoadingApp());
  final store = FinanceStore();
  await store.load();
  runApp(FinanceApp(store: store));
}
