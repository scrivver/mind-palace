import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeService themeService;
  final ValueChanged<ThemeSetting> onThemeChanged;
  final String authentikBase;

  const SettingsScreen({
    super.key,
    required this.themeService,
    required this.onThemeChanged,
    required this.authentikBase,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeSetting _selectedTheme = ThemeSetting.mindPalace;
  bool _loading = true;
  StreamSubscription<ThemeSetting>? _themeSubscription;

  @override
  void initState() {
    super.initState();
    _loadTheme();
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

  Future<void> _loadTheme() async {
    final theme = await widget.themeService.getTheme();
    if (mounted) {
      setState(() {
        _selectedTheme = theme;
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    final uri = Uri.parse(
        '${widget.authentikBase}/if/flow/password-reset/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
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
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Manage your sanctuary preferences and security settings.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildResetPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reset Password',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        SizedBox(
          width: 480,
          child: OutlinedButton.icon(
            onPressed: _resetPassword,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open password reset'),
          ),
        ),
      ],
    );
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
        if (_loading)
          const SizedBox(
            height: 112,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
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
