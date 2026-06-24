import 'package:flutter/material.dart';

class LoginView extends StatefulWidget {
  final VoidCallback onLogin;
  final Future<void> Function(String username, String password)?
  onPasswordLogin;
  final String? error;
  final bool loading;
  final bool isPasswordMode;
  final bool isOidcMode;
  final VoidCallback? onConfigureServer;

  const LoginView({
    super.key,
    required this.onLogin,
    this.onPasswordLogin,
    this.error,
    this.loading = false,
    this.isPasswordMode = false,
    this.isOidcMode = false,
    this.onConfigureServer,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;
    await widget.onPasswordLogin?.call(username, password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBrandHeader(theme),
                    const SizedBox(height: 32),
                    _buildLoginCard(context),
                  ],
                ),
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.castle, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text('Mind Palace', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          'Digital Sanctuary',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 0.2 * 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter your sanctuary.', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          if (widget.isPasswordMode) ...[
            TextField(
              controller: _usernameController,
              focusNode: _usernameFocus,
              enabled: !widget.loading,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              enabled: !widget.loading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitPassword(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: widget.loading
                      ? null
                      : () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (widget.isPasswordMode)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: widget.loading ? null : _submitPassword,
                child: widget.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Sign In',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.onPrimary,
                        ),
                      ),
              ),
            ),
          if (widget.isPasswordMode && widget.isOidcMode)
            const SizedBox(height: 12),
          if (widget.isOidcMode)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: widget.isPasswordMode
                  ? OutlinedButton(
                      onPressed: widget.loading ? null : widget.onLogin,
                      child: const Text('Sign in with SSO'),
                    )
                  : FilledButton(
                      onPressed: widget.loading ? null : widget.onLogin,
                      child: Text(
                        'Sign in with SSO',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
            ),
          if (widget.error != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.error!,
              style: TextStyle(color: cs.error),
              textAlign: TextAlign.center,
            ),
          ],
          if (widget.onConfigureServer != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: widget.onConfigureServer,
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Change Server'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return _buildFooterMobile(theme);
              }
              return _buildFooterDesktop(theme);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFooterDesktop(ThemeData theme) {
    final cs = theme.colorScheme;
    final meta = theme.textTheme.bodySmall;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mind Palace',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
            Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: cs.outlineVariant,
            ),
            Text(
              '\u00a9 2026 Mind Palace. Architectural Precision for your Digital Assets.',
              style: meta?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _footerLink(theme, 'Privacy Policy'),
            const SizedBox(width: 16),
            _footerLink(theme, 'Terms of Service'),
            const SizedBox(width: 16),
            _footerLink(theme, 'Security Architecture'),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterMobile(ThemeData theme) {
    final cs = theme.colorScheme;
    final meta = theme.textTheme.bodySmall;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Mind Palace',
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          '\u00a9 2026 Mind Palace. Architectural Precision for your Digital Assets.',
          style: meta?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _footerLink(theme, 'Privacy Policy'),
            _footerLink(theme, 'Terms of Service'),
            _footerLink(theme, 'Security Architecture'),
          ],
        ),
      ],
    );
  }

  Widget _footerLink(ThemeData theme, String label) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
