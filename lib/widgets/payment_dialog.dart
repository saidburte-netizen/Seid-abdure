import 'package:flutter/material.dart';

import '../data/formatting.dart';
import 'common.dart';

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    required this.title,
    required this.accounts,
    this.defaultAmount,
    this.methods = const {
      'cash': 'Cash',
      'telebirr': 'TeleBirr',
      'cbe_birr': 'CBE Birr',
      'bank': 'Bank transfer',
      'other': 'Other',
    },
    super.key,
  });

  final String title;
  final List<Map<String, dynamic>> accounts;
  final num? defaultAmount;
  final Map<String, String> methods;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  String? _accountId;
  late String _method = widget.methods.keys.first;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.isEmpty
        ? null
        : widget.accounts.first['id'] as String?;
    if (widget.defaultAmount != null && widget.defaultAmount! > 0) {
      _amount.text = widget.defaultAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _accountId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Account'),
            items: [
              for (final account in widget.accounts)
                DropdownMenuItem(
                  value: account['id'] as String,
                  child: Text(
                    '${asText(account['name'])}'
                    '${account['balance'] == null ? '' : ' • ${formatMoney(account['balance'])}'}',
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _accountId = value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Method'),
            items: [
              for (final entry in widget.methods.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) =>
                setState(() => _method = value ?? widget.methods.keys.first),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (ETB)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Reference (optional)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_accountId == null) {
            showSnack(context, 'Choose an account.', error: true);
            return;
          }
          final amount = asNum(_amount.text);
          if (amount <= 0) {
            showSnack(context, 'Enter a positive amount.', error: true);
            return;
          }
          Navigator.of(context).pop({
            'account_id': _accountId,
            'amount': amount,
            'method': _method,
            'reference': _reference.text.trim(),
          });
        },
        child: const Text('Record payment'),
      ),
    ],
  );
}
