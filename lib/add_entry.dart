// ignore_for_file: deprecated_member_use

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'currency.dart';
import 'models.dart';
import 'store.dart';

const kExpenseCategories = [
  'Transport',
  'Loyer',
  'Fournitures',
  'Énergie / eau',
  'Salaires',
  'Autre',
];

class AddEntrySheet extends StatefulWidget {
  const AddEntrySheet({
    required this.store,
    required this.defaultCurrency,
    this.initialEntry,
    super.key,
  });

  final CashStore store;
  final String defaultCurrency;
  final CashEntry? initialEntry;

  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> {
  final labelController = TextEditingController();
  final amountController = TextEditingController();
  final customerController = TextEditingController();
  final noteController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  EntryType type = EntryType.sale;
  bool isPaid = true;
  bool useCatalog = false;
  bool isSaving = false;
  bool removeExistingAttachment = false;
  late String currency;
  String expenseCategory = 'Autre';
  String? selectedProductId;
  PlatformFile? selectedAttachment;
  final Map<String, double> cart = {};

  bool get isEditing => widget.initialEntry != null;
  bool get isCatalogSale => widget.initialEntry?.saleItems.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    currency = entry?.currency ?? widget.defaultCurrency;
    if (entry != null) {
      labelController.text = entry.label;
      amountController.text = entry.amount.toString();
      customerController.text = entry.customer ?? '';
      noteController.text = entry.note ?? '';
      type = entry.type;
      isPaid = entry.isPaid;
      expenseCategory = entry.expenseCategory ?? 'Autre';
    }
  }

  @override
  void dispose() {
    labelController.dispose();
    amountController.dispose();
    customerController.dispose();
    noteController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  List<Product> get currencyProducts => widget.store.activeProducts
      .where((product) => product.currency == currency)
      .toList();

  int get cartTotal => cart.entries.fold(0, (sum, item) {
    final product = widget.store.productById(item.key);
    if (product == null) return sum;
    return sum + (product.unitPrice * item.value).round();
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final lockedCatalogSale = isEditing && isCatalogSale;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Modifier l’opération' : 'Nouvelle opération',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (!isEditing)
              SegmentedButton<EntryType>(
                segments: const [
                  ButtonSegment(
                    value: EntryType.sale,
                    label: Text('Vente'),
                    icon: Icon(Icons.add_shopping_cart),
                  ),
                  ButtonSegment(
                    value: EntryType.expense,
                    label: Text('Dépense'),
                    icon: Icon(Icons.shopping_cart_checkout),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (value) => setState(() {
                  type = value.first;
                  useCatalog = false;
                }),
              ),
            if (type == EntryType.sale &&
                !isEditing &&
                currencyProducts.isNotEmpty) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vente depuis le catalogue'),
                subtitle: const Text('Le stock sera diminué à la vente'),
                value: useCatalog,
                onChanged: (value) => setState(() {
                  useCatalog = value;
                  cart.clear();
                  selectedProductId = null;
                }),
              ),
            ],
            if (lockedCatalogSale)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Vente catalogue : ${widget.initialEntry!.saleItems.map((line) => '${line.label} × ${_quantity(line.quantity)} ${line.unit}').join(', ')}. Les articles et le total ne sont pas modifiables ici.',
                ),
              ),
            if (type == EntryType.sale && useCatalog && !isEditing) ...[
              const SizedBox(height: 8),
              if (currencyProducts.isEmpty)
                const Text('Aucun produit disponible dans cette devise.')
              else ...[
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'Produit',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: currencyProducts
                      .map(
                        (product) => DropdownMenuItem(
                          value: product.id,
                          child: Text(
                            '${product.name} · ${formatAmount(product.unitPrice, product.currency)} / ${product.unit} · stock ${_quantity(product.stockQuantity)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedProductId = value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*([,.]\d*)?$'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Quantité',
                          prefixIcon: Icon(Icons.scale_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: _addProductToCart,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                    ),
                  ],
                ),
                if (cart.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...cart.entries.map((item) {
                    final product = widget.store.productById(item.key);
                    if (product == null) return const SizedBox.shrink();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(product.name),
                      subtitle: Text(
                        '${_quantity(item.value)} ${product.unit} × ${formatAmount(product.unitPrice, currency)}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Retirer',
                        onPressed: () => setState(() => cart.remove(item.key)),
                        icon: const Icon(Icons.close),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Total (${currencySymbol(currency)})',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  child: Text(
                    formatAmount(cartTotal, currency),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ] else if (!lockedCatalogSale) ...[
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                autofocus: !isEditing,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: type == EntryType.sale
                      ? 'Article ou service'
                      : 'Motif de la dépense',
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Montant (${currencySymbol(currency)})',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: currency,
              decoration: const InputDecoration(
                labelText: 'Devise',
                prefixIcon: Icon(Icons.currency_exchange),
              ),
              items: kCurrencies.entries
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.key,
                      child: Text(item.value),
                    ),
                  )
                  .toList(),
              onChanged: isCatalogSale
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          currency = value;
                          cart.clear();
                          selectedProductId = null;
                        });
                      }
                    },
            ),
            if (type == EntryType.sale) ...[
              const SizedBox(height: 12),
              TextField(
                controller: customerController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Client (optionnel)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Payé immédiatement'),
                subtitle: const Text('Décochez pour enregistrer une dette'),
                value: isPaid,
                onChanged: lockedCatalogSale
                    ? null
                    : (value) => setState(() => isPaid = value),
              ),
            ],
            if (type == EntryType.expense) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: kExpenseCategories.contains(expenseCategory)
                    ? expenseCategory
                    : 'Autre',
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: kExpenseCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => expenseCategory = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (facultative)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 8),
              _buildAttachmentPicker(context),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: isSaving ? null : _submit,
              child: Text(isSaving ? 'Enregistrement…' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPicker(BuildContext context) {
    final currentName =
        selectedAttachment?.name ??
        (removeExistingAttachment ? null : widget.initialEntry?.attachmentName);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickAttachment,
            icon: const Icon(Icons.attach_file),
            label: Text(
              currentName ?? 'Ajouter un justificatif (PDF/image, 1 Mo max.)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (currentName != null)
          IconButton(
            tooltip: 'Retirer le justificatif',
            onPressed: () => setState(() {
              selectedAttachment = null;
              removeExistingAttachment =
                  widget.initialEntry?.attachmentName != null;
            }),
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) {
        _showMessage('Impossible de lire ce fichier.');
        return;
      }
      if (file.bytes!.length > 1024 * 1024) {
        _showMessage('Le justificatif ne doit pas dépasser 1 Mo.');
        return;
      }
      setState(() {
        selectedAttachment = file;
        removeExistingAttachment = false;
      });
    } catch (_) {
      _showMessage('Impossible d’ouvrir le sélecteur de fichiers.');
    }
  }

  void _addProductToCart() {
    final productId = selectedProductId;
    final product = productId == null
        ? null
        : widget.store.productById(productId);
    final quantity = double.tryParse(
      quantityController.text.trim().replaceAll(',', '.'),
    );
    if (product == null || quantity == null || quantity <= 0) {
      _showMessage('Choisissez un produit et une quantité valide.');
      return;
    }
    final alreadyAdded = cart[product.id] ?? 0;
    if (alreadyAdded + quantity > product.stockQuantity + 0.000001) {
      _showMessage('Stock insuffisant pour ${product.name}.');
      return;
    }
    setState(() {
      cart.update(
        product.id,
        (value) => value + quantity,
        ifAbsent: () => quantity,
      );
      quantityController.text = '1';
    });
  }

  Future<void> _submit() async {
    if (isSaving) return;
    final label = labelController.text.trim();
    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    if (type == EntryType.sale && useCatalog && !isEditing && cart.isEmpty) {
      _showMessage('Ajoutez au moins un article à la vente.');
      return;
    }
    if (!(type == EntryType.sale && useCatalog && !isEditing) &&
        !isCatalogSale &&
        (label.isEmpty || amount <= 0)) {
      _showMessage('Renseignez un libellé et un montant valide.');
      return;
    }

    setState(() => isSaving = true);
    try {
      final entry = widget.initialEntry;
      if (entry != null) {
        await widget.store.updateEntry(
          original: entry,
          label: label.isEmpty ? entry.label : label,
          amount: amount <= 0 ? entry.amount : amount,
          currency: currency,
          customer: customerController.text,
          isPaid: isPaid,
          expenseCategory: type == EntryType.expense ? expenseCategory : null,
          note: noteController.text,
          clearNote:
              type == EntryType.expense && noteController.text.trim().isEmpty,
          attachmentBytes: selectedAttachment?.bytes,
          attachmentName: selectedAttachment?.name,
          attachmentMimeType: _mimeType(selectedAttachment),
          removeAttachment: removeExistingAttachment,
        );
      } else if (type == EntryType.sale && useCatalog) {
        await widget.store.addCatalogSale(
          quantities: Map<String, double>.from(cart),
          customer: customerController.text,
          isPaid: isPaid,
          currency: currency,
        );
      } else if (type == EntryType.sale) {
        await widget.store.addSale(
          label: label,
          amount: amount,
          customer: customerController.text,
          isPaid: isPaid,
          currency: currency,
        );
      } else {
        await widget.store.addExpense(
          label: label,
          amount: amount,
          currency: currency,
          category: expenseCategory,
          note: noteController.text,
          attachmentBytes: selectedAttachment?.bytes,
          attachmentName: selectedAttachment?.name,
          attachmentMimeType: _mimeType(selectedAttachment),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _showMessage(
        error is StateError || error is ArgumentError
            ? error
                  .toString()
                  .replaceFirst('Bad state: ', '')
                  .replaceFirst('Invalid argument(s): ', '')
            : 'Impossible d’enregistrer cette opération.',
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  String? _mimeType(PlatformFile? file) {
    switch (file?.extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return null;
    }
  }

  String _quantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
