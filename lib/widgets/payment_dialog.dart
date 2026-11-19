import 'package:flutter/material.dart';

import '../data/formatting.dart';
import 'common.dart';
import '../l10n/ui_text.dart';

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    required this.title,
    required this.accounts,
    required this.maximum,
    required this.onSave,
    this.methods = const [
      'cash',
      'bank',
      'telebirr',
      'cbe_birr',
      'mobile_money',
      'card',
    ],
    super.key,
  });

  final String title;
  final List<Map<String, dynamic>> accounts;
  final num maximum;
  final List<String> methods;
  final Future<void> Function(Map<String, dynamic> payment) onSave;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late final _amount = TextEditingController(
    text: widget.maximum.toStringAsFixed(2),
  );
  final _reference = TextEditingController();
  late String _account = widget.accounts.first['id'] as String;
  late String _method = widget.methods.first;
  bool _saving = false;
  Object? _error;
  String? _amountError;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = num.tryParse(_amount.text.trim());
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > widget.maximum) {
      setState(() {
        _error = null;
        _amountError = amount != null && amount > widget.maximum
            ? 'Amount cannot exceed ${formatMoney(widget.maximum)}.'
            : 'Enter an amount greater than zero.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _amountError = null;
    });
    try {
      await widget.onSave({
        'account': _account,
        'amount': amount,
        'method': _method,
        'reference': _reference.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            FriendlyErrorBox(error: _error!),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            initialValue: _account,
            decoration: InputDecoration(
              labelText: uiText(context, 'Cash account'),
            ),
            items: [
              for (final account in widget.accounts)
                DropdownMenuItem(
                  value: account['id'] as String,
                  child: Text(asText(account['name'])),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _account = value ?? _account),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: uiText(context, 'Amount'),
              errorText: _amountError,
              helperText: 'Maximum ${formatMoney(widget.maximum)}',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: InputDecoration(labelText: uiText(context, 'Method')),
            items: [
              for (final method in widget.methods)
                DropdownMenuItem(
                  value: method,
                  child: Text(
                    uiText(context, switch (method) {
                      'cbe_birr' => 'CBE Birr',
                      'mobile_money' => 'Mobile money',
                      _ => prettyLabel(method),
                    }),
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _method = value ?? _method),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reference,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: uiText(context, 'Reference'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const LText('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(uiText(context, _saving ? 'Saving…' : 'Record payment')),
        ),
      ],
    ),
  );
}
