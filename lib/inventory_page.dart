import 'package:flutter/material.dart';

import 'currency.dart';
import 'models.dart';
import 'settings.dart';
import 'store.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({required this.store, required this.settings, super.key});

  final CashStore store;
  final AppSettings settings;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  static const _teal = Color(0xff0f766e);
  bool get _english => widget.settings.localeCode == 'en';
  String _text(String fr, String en) => _english ? en : fr;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStoreChanged);
      widget.store.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.store.activeProducts;
    final lowStock = widget.store.lowStockProducts;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _text('Inventaire', 'Inventory'),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showProductForm(),
              icon: const Icon(Icons.add),
              label: Text(_text('Ajouter', 'Add')),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _text(
            'Suivez vos produits et les quantités disponibles.',
            'Keep track of your products and available quantities.',
          ),
        ),
        const SizedBox(height: 16),
        _SummaryCard(
          count: products.length,
          alertCount: lowStock.length,
          onAlertsTap: lowStock.isEmpty ? null : () => _showLowStock(lowStock),
          title: _text('Produits actifs', 'Active products'),
          alertLabel: _text('en alerte', 'low stock'),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                _text('Catalogue', 'Catalog'),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (lowStock.isNotEmpty)
              TextButton.icon(
                onPressed: () => _showLowStock(lowStock),
                icon: const Icon(Icons.warning_amber_rounded),
                label: Text(
                  _text(
                    'Alertes (${lowStock.length})',
                    'Alerts (${lowStock.length})',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (products.isEmpty)
          _EmptyInventory(
            message: _text('Aucun produit pour le moment.', 'No products yet.'),
          )
        else
          ...products.map(_productCard),
      ],
    );
  }

  Widget _productCard(Product product) {
    final low = product.isLowStock;
    final empty = product.stockQuantity <= 0;
    final status = empty
        ? _text('Rupture de stock', 'Out of stock')
        : low
        ? _text('Stock bas', 'Low stock')
        : _text('En stock', 'In stock');
    final statusColor = empty
        ? Theme.of(context).colorScheme.error
        : low
        ? Colors.orange.shade800
        : _teal;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _teal.withValues(alpha: 0.12),
                  foregroundColor: _teal,
                  child: const Icon(Icons.inventory_2_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatAmount(product.unitPrice, product.currency)} / ${product.unit}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: _text('Actions', 'Actions'),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showProductForm(product: product);
                      case 'history':
                        _showHistory(product);
                      case 'archive':
                        _confirmArchive(product);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(_text('Modifier', 'Edit')),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'history',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history),
                        title: Text(_text('Historique', 'History')),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.archive_outlined),
                        title: Text(_text('Désactiver', 'Deactivate')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_quantity(product.stockQuantity)} ${product.unit}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${_text('Seuil d’alerte', 'Low-stock threshold')}: ${_quantity(product.lowStockThreshold)} ${product.unit}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAdjustment(product, incoming: true),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_text('Entrée', 'Stock in')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showAdjustment(product, incoming: false),
                  icon: const Icon(Icons.remove, size: 18),
                  label: Text(_text('Sortie', 'Stock out')),
                ),
                TextButton.icon(
                  onPressed: () => _showHistory(product),
                  icon: const Icon(Icons.history, size: 18),
                  label: Text(_text('Mouvements', 'Movements')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _quantity(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  void _showLowStock(List<Product> products) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              _text('Alertes de stock', 'Stock alerts'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ...products.map(
              (product) => ListTile(
                leading: Icon(
                  product.stockQuantity <= 0
                      ? Icons.remove_shopping_cart_outlined
                      : Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(product.name),
                subtitle: Text(
                  '${product.stockQuantity <= 0 ? _text('Rupture', 'Out of stock') : _text('Stock bas', 'Low stock')} · ${_quantity(product.stockQuantity)} ${product.unit}',
                ),
                trailing: IconButton(
                  tooltip: _text('Ajouter du stock', 'Add stock'),
                  onPressed: () {
                    Navigator.pop(context);
                    _showAdjustment(product, incoming: true);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProductForm({Product? product}) async {
    final isEditing = product != null;
    final name = TextEditingController(text: product?.name ?? '');
    final unit = TextEditingController(text: product?.unit ?? 'pièce');
    final price = TextEditingController(
      text: product == null ? '' : product.unitPrice.toString(),
    );
    final quantity = TextEditingController(text: '0');
    final threshold = TextEditingController(
      text: _quantity(product?.lowStockThreshold ?? 5),
    );
    var currency = product?.currency ?? widget.settings.defaultCurrency;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isEditing
                ? _text('Modifier le produit', 'Edit product')
                : _text('Nouveau produit', 'New product'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  name,
                  label: _text('Nom du produit', 'Product name'),
                  icon: Icons.inventory_2_outlined,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        unit,
                        label: _text('Unité', 'Unit'),
                        hint: 'pièce, kg, L',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        price,
                        label: _text('Prix unitaire', 'Unit price'),
                        keyboardType: TextInputType.number,
                        prefix: currencySymbol(currency),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isEditing) ...[
                  _field(
                    quantity,
                    label: _text('Stock initial', 'Opening stock'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _field(
                  threshold,
                  label: _text('Seuil d’alerte', 'Low-stock threshold'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: InputDecoration(
                    labelText: _text('Devise', 'Currency'),
                    border: const OutlineInputBorder(),
                  ),
                  items: kCurrencies.keys
                      .map(
                        (code) => DropdownMenuItem(
                          value: code,
                          child: Text('$code · ${currencySymbol(code)}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => currency = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_text('Annuler', 'Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final parsedPrice = int.tryParse(price.text.trim());
                final parsedQuantity = _parseQuantity(quantity.text);
                final parsedThreshold = _parseQuantity(threshold.text);
                if (name.text.trim().isEmpty ||
                    parsedPrice == null ||
                    parsedPrice <= 0 ||
                    (!isEditing &&
                        (parsedQuantity == null || parsedQuantity < 0)) ||
                    parsedThreshold == null ||
                    parsedThreshold < 0) {
                  _message(
                    _text(
                      'Produit ou quantité invalide.',
                      'Invalid product or quantity.',
                    ),
                  );
                  return;
                }
                try {
                  if (isEditing) {
                    await widget.store.updateProduct(
                      id: product.id,
                      name: name.text,
                      unit: unit.text,
                      unitPrice: parsedPrice,
                      lowStockThreshold: parsedThreshold,
                      currency: currency,
                    );
                  } else {
                    await widget.store.addProduct(
                      name: name.text,
                      unit: unit.text,
                      unitPrice: parsedPrice,
                      initialQuantity: parsedQuantity!,
                      lowStockThreshold: parsedThreshold,
                      currency: currency,
                    );
                  }
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  _message(_friendlyError(error));
                }
              },
              child: Text(_text('Enregistrer', 'Save')),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    unit.dispose();
    price.dispose();
    quantity.dispose();
    threshold.dispose();
    if (result == true && mounted) {
      _message(_text('Produit enregistré.', 'Product saved.'));
    }
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? prefix,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix == null ? null : '$prefix ',
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    ),
  );

  double? _parseQuantity(String input) =>
      double.tryParse(input.trim().replaceAll(',', '.'));

  Future<void> _showAdjustment(
    Product product, {
    required bool incoming,
  }) async {
    final quantity = TextEditingController();
    final note = TextEditingController();
    final result = await showDialog<(double, String?)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          incoming
              ? _text('Entrée de stock', 'Stock received')
              : _text('Sortie de stock', 'Stock removed'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${product.name} · ${_text('Disponible', 'Available')}: ${_quantity(product.stockQuantity)} ${product.unit}',
              ),
            ),
            const SizedBox(height: 14),
            _field(
              quantity,
              label: _text('Quantité', 'Quantity'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            _field(
              note,
              label: _text('Note (facultative)', 'Note (optional)'),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_text('Annuler', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final amount = _parseQuantity(quantity.text);
              if (amount == null || !amount.isFinite || amount <= 0) {
                _message(
                  _text(
                    'Saisissez une quantité valide.',
                    'Enter a valid quantity.',
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, (amount, note.text.trim()));
            },
            child: Text(_text('Confirmer', 'Confirm')),
          ),
        ],
      ),
    );
    quantity.dispose();
    note.dispose();
    if (result == null) return;
    try {
      await widget.store.adjustStock(
        productId: product.id,
        quantityDelta: incoming ? result.$1 : -result.$1,
        reason: incoming ? 'Entrée de stock' : 'Sortie de stock',
        note: result.$2,
      );
      if (mounted) {
        _message(_text('Stock mis à jour.', 'Stock updated.'));
      }
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    final value = error.toString();
    if (value.contains('Stock insuffisant')) {
      return _text(
        'Stock insuffisant pour cette sortie.',
        'Not enough stock for this removal.',
      );
    }
    if (value.contains('introuvable') ||
        value.contains('supprimé') ||
        value.contains('invalide') ||
        value.contains('ArgumentError')) {
      return _text(
        'Produit invalide ou introuvable.',
        'Invalid or unavailable product.',
      );
    }
    return _text(
      'Opération impossible. Réessayez.',
      'Operation failed. Please try again.',
    );
  }

  Future<void> _confirmArchive(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _text('Désactiver ce produit ?', 'Deactivate this product?'),
        ),
        content: Text(
          _text(
            '${product.name} sera retiré du catalogue actif. Son historique est conservé.',
            '${product.name} will be removed from the active catalog. Its history is preserved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text('Annuler', 'Cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text('Désactiver', 'Deactivate')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.store.archiveProduct(product.id);
      if (mounted) {
        _message(
          _text(
            'Produit désactivé. Son historique est conservé.',
            'Product deactivated. Its history is preserved.',
          ),
        );
      }
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    }
  }

  void _showHistory(Product product) {
    final movements = widget.store.movementsForProduct(product.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  _text(
                    'Mouvements · ${product.name}',
                    'Movements · ${product.name}',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: movements.isEmpty
                    ? Center(
                        child: Text(
                          _text(
                            'Aucun mouvement enregistré.',
                            'No stock movements recorded.',
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        itemCount: movements.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final movement = movements[index];
                          final isIn = movement.quantityDelta > 0;
                          final color = isIn
                              ? _teal
                              : Theme.of(context).colorScheme.error;
                          final signed =
                              '${isIn ? '+' : ''}${_quantity(movement.quantityDelta)} ${product.unit}';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.12),
                              foregroundColor: color,
                              child: Icon(
                                isIn
                                    ? Icons.south_west_rounded
                                    : Icons.north_east_rounded,
                              ),
                            ),
                            title: Text(
                              movement.reason,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                formatDate(movement.createdAt),
                                if (movement.note?.isNotEmpty == true)
                                  movement.note!,
                              ].join(' · '),
                            ),
                            trailing: Text(
                              signed,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.count,
    required this.alertCount,
    required this.onAlertsTap,
    required this.title,
    required this.alertLabel,
  });

  final int count;
  final int alertCount;
  final VoidCallback? onAlertsTap;
  final String title;
  final String alertLabel;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xff0f766e),
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (alertCount > 0)
            TextButton.icon(
              onPressed: onAlertsTap,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
              ),
              icon: const Icon(Icons.warning_amber_rounded),
              label: Text('$alertCount $alertLabel'),
            )
          else
            const Icon(Icons.check_circle_outline, color: Colors.white70),
        ],
      ),
    ),
  );
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 38,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
