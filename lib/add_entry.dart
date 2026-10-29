// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'currency.dart';
import 'models.dart';
import 'store.dart';

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
  EntryType type = EntryType.sale;
  bool isPaid = true;
  late String currency;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    currency = entry?.currency ?? widget.defaultCurrency;
    if (entry != null) {
      labelController.text = entry.label;
      amountController.text = entry.amount.toString();
      customerController.text = entry.customer ?? '';
      type = entry.type;
      isPaid = entry.isPaid;
    }
  }

  @override
  void dispose() {
    labelController.dispose();
    amountController.dispose();
    customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialEntry == null
                  ? 'Nouvelle opération'
                  : 'Modifier l’opération',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
              onSelectionChanged: (value) => setState(() => type = value.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: labelController,
              autofocus: true,
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: currency,
              decoration: const InputDecoration(
                labelText: 'Devise',
                prefixIcon: Icon(Icons.currency_exchange),
              ),
              items: kCurrencies.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => currency = v);
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
                onChanged: (v) => setState(() => isPaid = v),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final label = labelController.text.trim();
    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    if (label.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renseignez un libellé et un montant valide.'),
        ),
      );
      return;
    }
    if (widget.initialEntry != null) {
      await widget.store.updateEntry(
        original: widget.initialEntry!,
        label: label,
        amount: amount,
        currency: currency,
        customer: customerController.text,
        isPaid: isPaid,
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
      );
    }
    if (mounted) Navigator.pop(context);
  }
}
