import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/server_url_store.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeService themeService;
  final ThemeSetting currentTheme;
  final ValueChanged<ThemeSetting> onThemeChanged;
  final bool isExternalIdp;
  final String authentikBase;
  final VoidCallback onServerUrlChanged;

  const SettingsScreen({
    super.key,
    required this.themeService,
    required this.currentTheme,
    required this.onThemeChanged,
    required this.isExternalIdp,
    this.authentikBase = '',
    required this.onServerUrlChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeSetting _selectedTheme;
  StreamSubscription<ThemeSetting>? _themeSubscription;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
    _themeSubscription = widget.themeService.themeModeStream.listen((setting) {
      if (mounted) {
        setState(() => _selectedTheme = setting);
      }
    });
  }

  @override
  void dispose() {
    _themeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (widget.authentikBase.isEmpty) return;
    final uri = Uri.parse(
        '${widget.authentikBase}/if/flow/password-reset/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
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
        Text('Settings',
            style: Theme.of(context).textTheme.headlineLarge),
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
        Text('Server Connection',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Configure the Mind Palace server endpoint.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reset Password',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        if (widget.isExternalIdp) ..._buildExternalIdpForm(colors)
        else SizedBox(
          width: 480,
          child: OutlinedButton.icon(
            onPressed: widget.authentikBase.isNotEmpty ? _resetPassword : null,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open password reset'),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildExternalIdpForm(ColorScheme colors) {
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withAlpha(128),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: 18, color: colors.onSurfaceVariant),
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
      const SizedBox(height: 24),
      SizedBox(
        width: 480,
        child: Column(
          children: [
            TextFormField(
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: null,
                child: const Text('Reset Password'),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildThemeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Theme Preference',
            style: Theme.of(context).textTheme.titleMedium),
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
              .map((setting) => SizedBox(
                    width: 180,
                    child: _buildThemeCard(setting),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildThemeCard(ThemeSetting setting) {
    final isSelected = _selectedTheme == setting;
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedTheme = setting);
          widget.themeService.setTheme(setting);
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
                  Text(setting.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          )),
                  if (setting.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        setting.subtitle!,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.primary,
                                ),
                      ),
                    ),
                ],
              ),
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.check_circle,
                      color: colors.primary, size: 20),
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
