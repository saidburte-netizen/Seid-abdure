import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_controller.dart';
import '../../core/logging/app_logger.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _uploading = false;
  bool _dirty = false;
  String? _savedName;
  String? _savedPhone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final session = SessionScope.of(context);
    _savedName = session.fullName ?? '';
    _savedPhone = session.phone ?? '';
    _name.text = _savedName!;
    _phone.text = _savedPhone!;
    _loaded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _updateDirty() {
    final dirty =
        _name.text.trim() != _savedName || _phone.text.trim() != _savedPhone;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await SessionScope.of(
        context,
      ).updateProfile(fullName: _name.text, phone: _phone.text);
      if (!mounted) return;
      setState(() {
        _savedName = _name.text.trim();
        _savedPhone = _phone.text.trim();
        _dirty = false;
      });
      showSnack(context, AppLocalizations.of(context).profileUpdated);
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadAvatar() async {
    final session = SessionScope.of(context);
    final userId = session.userId;
    if (userId == null) return;
    final strings = AppLocalizations.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (picked == null) return;
      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final path =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await session.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      final publicUrl = session.client.storage
          .from('avatars')
          .getPublicUrl(path);
      await session.updateProfile(avatarUrl: publicUrl);
      if (!mounted) return;
      showSnack(context, strings.avatarUploaded);
    } catch (error, stack) {
      AppLogger.error('Could not upload the profile photo', error, stack);
      if (mounted) showFriendlyError(context, error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final strings = AppLocalizations.of(context);
    final branch = session.selectedBranch;
    final avatar = session.avatarUrl;
    return AppScaffold(
      title: Text(strings.profile),
      hasUnsavedChanges: _dirty,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  backgroundImage: avatar == null || avatar.isEmpty
                      ? null
                      : NetworkImage(avatar),
                  child: avatar == null || avatar.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 52,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
                IconButton.filled(
                  tooltip: strings.uploadAvatar,
                  onPressed: _uploading ? null : _uploadAvatar,
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: strings.fullName),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => _updateDirty(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? strings.requiredField
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: InputDecoration(labelText: strings.phone),
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => _updateDirty(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: Text(strings.email),
            subtitle: Text(session.userEmail ?? '—'),
            trailing: Tooltip(
              message: strings.emailReadOnly,
              child: const Icon(Icons.lock_outline, size: 18),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.badge_outlined),
            title: Text(branch?.roleLabel ?? '—'),
            subtitle: Text(branch?.branchName ?? '—'),
          ),
          const SizedBox(height: 20),
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
