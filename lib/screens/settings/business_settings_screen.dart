import 'dart:convert';

import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../core/errors/friendly_error.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/common.dart';
import '../../l10n/ui_text.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  final _businessName = TextEditingController();
  final _slogan = TextEditingController();
  final _currencyCode = TextEditingController();
  final _currencySymbol = TextEditingController();
  final _vat = TextEditingController();
  final _tot = TextEditingController();
  String _defaultLanguage = 'en';
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _businessName.dispose();
    _slogan.dispose();
    _currencyCode.dispose();
    _currencySymbol.dispose();
    _vat.dispose();
    _tot.dispose();
    super.dispose();
  }

  Map<String, dynamic> _decode(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return {'text': value};
      }
    }
    return const {};
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SessionScope.of(
        context,
      ).client.from('app_settings').select();
      final values = <String, dynamic>{
        for (final row in rows as List) row['key'] as String: row['value'],
      };
      final names = _decode(values['business_name']);
      final slogan = _decode(values['slogan']);
      final currency = _decode(values['currency']);
      final tax = _decode(values['tax']);
      final languages = _decode(values['languages']);
      if (!mounted) return;
      _businessName.text = (names['name'] ?? names['text'] ?? '').toString();
      _slogan.text = (slogan['text'] ?? slogan['name'] ?? '').toString();
      _currencyCode.text = (currency['code'] ?? 'ETB').toString();
      _currencySymbol.text = (currency['symbol'] ?? 'Br').toString();
      _vat.text = (tax['vat_rate'] ?? 15).toString();
      _tot.text = (tax['tot_rate'] ?? 2).toString();
      _defaultLanguage = (languages['default'] ?? 'en').toString();
      setState(() {
        _loading = false;
        _dirty = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyMessage(error);
      });
    }
  }

  Future<void> _save() async {
    final strings = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final client = SessionScope.of(context).client;
      final values = <String, Map<String, dynamic>>{
        'business_name': {'name': _businessName.text.trim()},
        'slogan': {'text': _slogan.text.trim()},
        'currency': {
          'code': _currencyCode.text.trim().toUpperCase(),
          'symbol': _currencySymbol.text.trim(),
        },
        'tax': {
          'vat_rate': num.tryParse(_vat.text.trim()) ?? 0,
          'tot_rate': num.tryParse(_tot.text.trim()) ?? 0,
        },
        'languages': {
          'default': _defaultLanguage,
          'supported': const ['en', 'am', 'om'],
        },
      };
      for (final entry in values.entries) {
        await client
            .from('app_settings')
            .update({'value': entry.value})
            .eq('key', entry.key);
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      showSnack(context, strings.saved);
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AppScaffold(
      title: Text(strings.businessSettings),
      hasUnsavedChanges: _dirty,
      actions: [
        IconButton(
          tooltip: strings.refresh,
          onPressed: _loading || _saving ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: strings.businessName,
                  child: TextField(
                    controller: _businessName,
                    decoration: InputDecoration(
                      labelText: strings.businessName,
                    ),
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                SectionCard(
                  title: strings.slogan,
                  child: TextField(
                    controller: _slogan,
                    decoration: InputDecoration(labelText: strings.slogan),
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                SectionCard(
                  title: strings.currency,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _currencyCode,
                          decoration: InputDecoration(
                            labelText: uiText(context, 'Code'),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => _markDirty(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _currencySymbol,
                          decoration: InputDecoration(
                            labelText: uiText(context, 'Symbol'),
                          ),
                          onChanged: (_) => _markDirty(),
                        ),
                      ),
                    ],
                  ),
                ),
                SectionCard(
                  title: uiText(context, 'Tax rates'),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _vat,
                          decoration: InputDecoration(
                            labelText: strings.vatRate,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _markDirty(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _tot,
                          decoration: InputDecoration(
                            labelText: strings.totRate,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _markDirty(),
                        ),
                      ),
                    ],
                  ),
                ),
                SectionCard(
                  title: strings.defaultLanguage,
                  child: DropdownButtonFormField<String>(
                    initialValue: _defaultLanguage,
                    decoration: InputDecoration(
                      labelText: strings.defaultLanguage,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
                      DropdownMenuItem(
                        value: 'om',
                        child: LText('Afaan Oromoo'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _defaultLanguage = value;
                        _dirty = true;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? strings.saving : strings.save),
                ),
              ],
            ),
    );
  }
}
