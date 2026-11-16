import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/common.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _signingOut = false;
  bool _dirty = false;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _updateDirty() {
    final dirty = _current.text.isNotEmpty ||
        _password.text.isNotEmpty ||
        _confirm.text.isNotEmpty;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    final session = SessionScope.of(context);
    final email = session.userEmail;
    setState(() => _saving = true);
    try {
      if (email == null || email.isEmpty) {
        throw const AuthException(
          'Your account has no email address. Contact an administrator.',
        );
      }
      await session.client.auth.signInWithPassword(
        email: email,
        password: _current.text,
      );
      await session.changePassword(_password.text);
      if (!mounted) return;
      _current.clear();
      _password.clear();
      _confirm.clear();
      setState(() => _dirty = false);
      showSnack(context, AppLocalizations.of(context).passwordUpdated);
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final strings = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: strings.signOut,
      message: strings.signOutConfirmation,
      confirmLabel: strings.signOut,
    );
    if (!confirmed || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await SessionScope.of(context).signOut();
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AppScaffold(
      title: Text(strings.security),
      hasUnsavedChanges: _dirty,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: strings.changePassword,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _current,
                    decoration: InputDecoration(
                      labelText: strings.currentPassword,
                    ),
                    obscureText: true,
                    onChanged: (_) => _updateDirty(),
                    validator: (value) => value == null || value.isEmpty
                        ? strings.requiredField
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(labelText: strings.newPassword),
                    obscureText: true,
                    onChanged: (_) => _updateDirty(),
                    validator: (value) => value == null || value.length < 8
                        ? strings.errorPasswordMin8
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    decoration: InputDecoration(
                      labelText: strings.confirmNewPassword,
                    ),
                    obscureText: true,
                    onChanged: (_) => _updateDirty(),
                    validator: (value) => value != _password.text
                        ? strings.errorPasswordsDoNotMatch
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _changePassword,
                      icon: const Icon(Icons.lock_reset_outlined),
                      label: Text(
                        _saving ? strings.saving : strings.changePassword,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionCard(
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _signingOut ? null : _signOut,
                icon: _signingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: Text(_signingOut ? strings.saving : strings.signOut),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
