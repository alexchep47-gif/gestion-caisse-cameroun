// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'currency.dart';
import 'l10n.dart';
import 'settings.dart';
import 'store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.store, required this.settings, super.key});

  final CashStore store;
  final AppSettings settings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final pinController = TextEditingController();
  final pinConfirmController = TextEditingController();

  @override
  void dispose() {
    pinController.dispose();
    pinConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final t = L10n(settings.localeCode);

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t.appearance,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: Text(t.darkMode),
                  subtitle: Text(t.themeLabel(settings.themeMode.name)),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(t.themeSystem),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(t.themeLight),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(t.themeDark),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) settings.setThemeMode(v);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(t.language),
                  trailing: DropdownButton<String>(
                    value: settings.localeCode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'fr', child: Text('Français')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) {
                      if (v != null) settings.setLocaleCode(v);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: Text(t.fontSize),
                  subtitle: Text(_fontLabel(settings.textScale, t)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SegmentedButton<double>(
                    segments: [
                      ButtonSegment(value: 1.0, label: Text(t.fontNormal)),
                      ButtonSegment(value: 1.15, label: Text(t.fontLarge)),
                      ButtonSegment(value: 1.3, label: Text(t.fontXLarge)),
                    ],
                    selected: {settings.textScale},
                    onSelectionChanged: (s) => settings.setTextScale(s.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.defaultCurrency,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: DropdownButtonFormField<String>(
                value: settings.defaultCurrency,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.currency_exchange),
                ),
                items: kCurrencies.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) settings.setDefaultCurrency(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.security,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(settings.hasPin ? t.changePin : t.setPin),
                  subtitle: Text(
                    settings.hasPin ? t.pinProtected : t.pinRecommended,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPinDialog(context, t),
                ),
                if (settings.hasPin)
                  ListTile(
                    leading: const Icon(Icons.lock_open_outlined),
                    title: Text(t.removePin),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(t.removePin),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(t.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(t.removePin),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await settings.setPin(null);
                    },
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(t.biometrics),
                  subtitle: Text(kIsWeb ? t.biometricsWeb : t.biometricsSub),
                  value: settings.biometricsEnabled && !kIsWeb,
                  onChanged: kIsWeb
                      ? null
                      : (v) async {
                          if (v && !settings.hasPin) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(t.setPin)));
                            return;
                          }
                          await settings.setBiometricsEnabled(v);
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.backup,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(t.exportBackup),
                  subtitle: Text(t.exportBackupSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportBackup(context),
                ),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: Text(t.restoreBackup),
                  subtitle: Text(t.restoreBackupSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importBackup(context, t),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    t.clearHistory,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () => _confirmClear(context, t),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Gestion Caisse Cameroun v1.2',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _fontLabel(double scale, L10n t) {
    if (scale >= 1.25) return t.fontXLarge;
    if (scale >= 1.1) return t.fontLarge;
    return t.fontNormal;
  }

  Future<void> _showPinDialog(BuildContext context, L10n t) async {
    pinController.clear();
    pinConfirmController.clear();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.settings.hasPin ? t.changePin : t.setPin),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'PIN (4-8)'),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinConfirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: InputDecoration(labelText: t.save),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final p1 = pinController.text;
              final p2 = pinConfirmController.text;
              if (p1.length < 4 || p1 != p2) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(t.wrongPin)));
                return;
              }
              await widget.settings.setPin(p1);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(t.save),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    final json = widget.store.exportBackupJson();
    final name =
        'sauvegarde-caisse-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}.json';
    try {
      await Share.shareXFiles([
        XFile.fromData(
          utf8.encode(json),
          mimeType: 'application/json',
          name: name,
        ),
      ], subject: 'Sauvegarde Gestion Caisse');
    } catch (_) {
      await Share.share(json, subject: 'Sauvegarde Gestion Caisse');
    }
  }

  Future<void> _importBackup(BuildContext context, L10n t) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.restoreBackup),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.restoreBackup),
          ),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    try {
      final count = await widget.store.restoreBackup(controller.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$count')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Error')));
      }
    }
  }

  Future<void> _confirmClear(BuildContext context, L10n t) async {
    if (widget.store.entries.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.clearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.clearHistory),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.store.clearHistory();
    }
  }
}
