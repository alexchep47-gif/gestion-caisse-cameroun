import 'package:flutter/material.dart';
import 'settings.dart';
import 'store.dart';
import 'dashboard.dart';
import 'add_entry.dart';
import 'settings_page.dart';

class CashHomePage extends StatefulWidget {
  const CashHomePage({
    required this.store,
    required this.settings,
    required this.onLock,
    super.key,
  });

  final CashStore store;
  final AppSettings settings;
  final VoidCallback onLock;

  @override
  State<CashHomePage> createState() => _CashHomePageState();
}

class _CashHomePageState extends State<CashHomePage> {
  int currentTab = 0;

  CashStore get store => widget.store;
  AppSettings get settings => widget.settings;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(store: store, settings: settings),
      EntriesPage(store: store, settings: settings),
      DebtsPage(store: store, settings: settings),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma caisse'),
        actions: [
          if (settings.hasPin)
            IconButton(
              tooltip: 'Verrouiller',
              onPressed: widget.onLock,
              icon: const Icon(Icons.lock_outline),
            ),
          IconButton(
            tooltip: 'Paramètres',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xff0f1419), Color(0xff15202b)]
                : const [Color(0xfff3fbf9), Color(0xffe7f2f7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: pages[currentTab],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (index) => setState(() => currentTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Résumé',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Ventes',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Dettes',
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context) async =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => AddEntrySheet(
          store: store,
          defaultCurrency: settings.defaultCurrency,
        ),
      );

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(
          store: store,
          settings: settings,
        ),
      ),
    );
  }
}
