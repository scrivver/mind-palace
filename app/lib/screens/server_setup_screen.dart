import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/server_url_store.dart';

class ServerSetupScreen extends StatefulWidget {
  final String initialUrl;
  final String? error;
  final VoidCallback onConfigured;

  const ServerSetupScreen({
    super.key,
    this.initialUrl = '',
    this.error,
    required this.onConfigured,
  });

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _controller = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialUrl;
    _error = widget.error;
  }

  @override
  void didUpdateWidget(ServerSetupScreen old) {
    super.didUpdateWidget(old);
    if (widget.error != old.error) {
      setState(() => _error = widget.error);
    }
    if (widget.initialUrl != old.initialUrl) {
      _controller.text = widget.initialUrl;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final baseUrl = _controller.text.trim();
    if (baseUrl.isEmpty) return;

    final engramUrl = ServerUrlStore.engramBaseUrlFromBase(baseUrl);

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${engramUrl}api/auth/config'),
      );
      if (response.statusCode != 200) {
        throw Exception('Status ${response.statusCode}');
      }
      if (!mounted) return;
      await ServerUrlStore.setBaseUrl(baseUrl);
      widget.onConfigured();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Unable to reach Mind Palace server';
      });
    }
  }

  Future<void> _useDefaults() async {
    await ServerUrlStore.reset();
    _controller.text = ServerUrlStore.baseServerUrl;
    setState(() => _error = null);
    widget.onConfigured();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Mind Palace',
                  style: theme.textTheme.headlineLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Server Connection',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Enter your Mind Palace server URL to begin.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'SERVER URL',
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 11,
                      letterSpacing: 0.08 * 11,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'http://192.168.1.50:2080',
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _connect(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: _checking ? null : _connect,
                    child: _checking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Connect'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _checking ? null : _useDefaults,
                  child: const Text('Reset to defaults'),
                ),
                const SizedBox(height: 48),
                Text(
                  'Mind Palace',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
