import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../reliquary_service.dart';
import '../services/server_url_store.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeSetting currentTheme;
  final ValueChanged<ThemeSetting> onThemeChanged;
  final ReliquaryService reliquary;
  final String? username;
  final String? provider;
  final VoidCallback onServerUrlChanged;

  const SettingsScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
    required this.reliquary,
    required this.username,
    required this.provider,
    required this.onServerUrlChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final username = widget.username;
    if (username == null) return;

    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError('Enter new password and confirmation.');
      return;
    }
    if (newPassword != confirmPassword) {
      _showError('New password and confirmation do not match.');
      return;
    }

    try {
      await widget.reliquary.changePassword(username, newPassword);
      if (!mounted) return;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showMessage('Password changed successfully');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to change password: $e');
    }
  }

  Future<void> _changeServerUrl() async {
    final controller = TextEditingController(
      text: ServerUrlStore.baseServerUrl,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.50:2080',
            labelText: 'SERVER URL',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;

    final baseUrl = result.trim();
    final success = await ServerUrlStore.validateUrl(baseUrl);
    if (!success) {
      if (!mounted) return;
      _showError('Could not reach server');
      return;
    }

    await ServerUrlStore.setBaseUrl(baseUrl);
    widget.onServerUrlChanged();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            if (!kIsWeb) _buildServerConnectionSection(),
            if (!kIsWeb) const SizedBox(height: 48),
            _buildResetPasswordSection(),
            const SizedBox(height: 48),
            _buildThemeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          'Manage your sanctuary preferences and security settings.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildServerConnectionSection() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Server Connection',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Configure the Mind Palace server endpoint.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withAlpha(128),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server URL',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ServerUrlStore.baseServerUrl,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: _changeServerUrl,
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResetPasswordSection() {
    final colors = Theme.of(context).colorScheme;
    final isPasswordProvider = widget.provider == 'password';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Change Password', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        if (isPasswordProvider)
          SizedBox(
            width: 480,
            child: Column(
              children: [
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _changePassword,
                    child: const Text('Change Password'),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withAlpha(128),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Password management is handled by your external identity provider.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildThemeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme Preference',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Select a visual atmosphere for your digital sanctuary.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: ThemeSetting.values
              .map(
                (setting) =>
                    SizedBox(width: 180, child: _buildThemeCard(setting)),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildThemeCard(ThemeSetting setting) {
    final isSelected = widget.currentTheme == setting;
    final colors = Theme.of(context).colorScheme;

    return Material(
      key: ValueKey(setting.name),
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onThemeChanged(setting);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? colors.primary : colors.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildColorPreview(setting),
                  const SizedBox(height: 12),
                  Text(
                    setting.displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (setting.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        setting.subtitle!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.primary),
                      ),
                    ),
                ],
              ),
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.check_circle,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorPreview(ThemeSetting setting) {
    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _previewBackground(setting),
        borderRadius: BorderRadius.circular(8),
        border: _previewBorder(setting),
      ),
      child: Center(
        child: Container(
          height: 4,
          width: 32,
          decoration: BoxDecoration(
            color: _previewBar(setting),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Color _previewBackground(ThemeSetting setting) {
    switch (setting) {
      case ThemeSetting.mindPalace:
        return Theme.of(context).colorScheme.primaryContainer;
      case ThemeSetting.midnight:
        return const Color(0xFF1d1b20);
      case ThemeSetting.warm:
        return const Color(0xFFfff7f0);
      case ThemeSetting.neutral:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  BoxBorder? _previewBorder(ThemeSetting setting) {
    if (setting == ThemeSetting.warm) {
      return Border.all(color: const Color(0xFFf0e0d0));
    }
    return null;
  }

  Color _previewBar(ThemeSetting setting) {
    switch (setting) {
      case ThemeSetting.mindPalace:
        return Theme.of(context).colorScheme.primary;
      case ThemeSetting.midnight:
        return Theme.of(context).colorScheme.outlineVariant.withAlpha(77);
      case ThemeSetting.warm:
        return const Color(0xFFe0a080);
      case ThemeSetting.neutral:
        return Theme.of(context).colorScheme.outline.withAlpha(51);
    }
  }
}
