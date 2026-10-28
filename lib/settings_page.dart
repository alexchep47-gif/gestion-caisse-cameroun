import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'currency.dart';
import 'settings.dart';
import 'store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.store,
    required this.settings,
    super.key,
  });

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Apparence',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Mode sombre'),
                  subtitle: Text(_themeLabel(settings.themeMode)),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('Système'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Clair'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Sombre'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) settings.setThemeMode(v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Devise par défaut',
            style: Theme.of(context)
                .textTheme
                .titleMedium
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
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
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
            'Sécurité',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(
                    settings.hasPin ? 'Modifier le code PIN' : 'Définir un code PIN',
                  ),
                  subtitle: Text(
                    settings.hasPin
                        ? 'Un code PIN protège l’accès à la caisse'
                        : 'Recommandé pour sécuriser vos données',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPinDialog(context),
                ),
                if (settings.hasPin)
                  ListTile(
                    leading: const Icon(Icons.lock_open_outlined),
                    title: const Text('Supprimer le code PIN'),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Supprimer le PIN ?'),
                          content: const Text(
                            'L’application ne demandera plus de code au démarrage.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Annuler'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await settings.setPin(null);
                    },
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biométrie'),
                  subtitle: Text(
                    kIsWeb
                        ? 'Non disponible sur le web'
                        : 'Déverrouiller avec empreinte / Face ID',
                  ),
                  value: settings.biometricsEnabled && !kIsWeb,
                  onChanged: kIsWeb
                      ? null
                      : (v) async {
                          if (v && !settings.hasPin) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Définissez d’abord un code PIN.',
                                ),
                              ),
                            );
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
            'Sauvegarde',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Exporter une sauvegarde'),
                  subtitle: const Text('Fichier JSON de toutes les opérations'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportBackup(context),
                ),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Restaurer une sauvegarde'),
                  subtitle: const Text('Importer un fichier JSON précédemment exporté'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importBackup(context),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Effacer tout l’historique',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () => _confirmClear(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Gestion Caisse Cameroun v1.1',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
      case ThemeMode.system:
        return 'Suivre le système';
    }
  }

  Future<void> _showPinDialog(BuildContext context) async {
    pinController.clear();
    pinConfirmController.clear();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          widget.settings.hasPin ? 'Modifier le PIN' : 'Définir un PIN',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Nouveau code PIN (4-8 chiffres)',
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinConfirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Confirmer le PIN',
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final p1 = pinController.text;
              final p2 = pinConfirmController.text;
              if (p1.length < 4 || p1 != p2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Le PIN doit faire 4 à 8 chiffres et les deux champs doivent correspondre.',
                    ),
                  ),
                );
                return;
              }
              await widget.settings.setPin(p1);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code PIN enregistré.')),
                );
              }
            },
            child: const Text('Enregistrer'),
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
      await Share.shareXFiles(
        [
          XFile.fromData(
            utf8.encode(json),
            mimeType: 'application/json',
            name: name,
          ),
        ],
        subject: 'Sauvegarde Gestion Caisse',
      );
    } catch (_) {
      await Share.share(json, subject: 'Sauvegarde Gestion Caisse');
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer une sauvegarde'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Collez ici le contenu JSON de la sauvegarde…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    try {
      final count = await widget.store.restoreBackup(controller.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sauvegarde restaurée ($count opérations).')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fichier de sauvegarde invalide.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    if (widget.store.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L’historique est déjà vide.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer l’historique ?'),
        content: const Text(
          'Toutes les ventes, dépenses et dettes seront supprimées de cet appareil. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.store.clearHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Historique effacé.')),
        );
      }
    }
  }
}
