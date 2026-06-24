import 'package:flutter/material.dart';

import '../reliquary_service.dart';

class AdminScreen extends StatefulWidget {
  final ReliquaryService reliquary;

  const AdminScreen({super.key, required this.reliquary});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await widget.reliquary.listUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnackBar('Failed to load users: $e');
      }
    }
  }

  Future<void> _createUser() async {
    final result = await showDialog<_CreateUserResult>(
      context: context,
      builder: (ctx) => const _CreateUserDialog(),
    );
    if (result == null) return;

    try {
      await widget.reliquary.createUser(result.username, result.password);
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to create user: $e');
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final username = user['username'] as String;
    final deactivated = user['deactivated'] == true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          deactivated ? 'Permanently delete user' : 'Deactivate user',
        ),
        content: Text(
          deactivated
              ? 'Permanently delete "$username" and all their stored files, thumbnails, and metadata? This action is irreversible.'
              : 'Deactivate "$username"? They will no longer be able to sign in. Their files will remain until you permanently delete the user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              deactivated ? 'DELETE PERMANENTLY' : 'DEACTIVATE',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.reliquary.deleteUser(username, permanent: deactivated);
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        deactivated
            ? 'Failed to permanently delete user: $e'
            : 'Failed to deactivate user: $e',
      );
    }
  }

  Future<void> _activateUser(String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-enable user'),
        content: Text(
          'Re-enable "$username"? They will be able to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('RE-ENABLE'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.reliquary.activateUser(username);
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to re-enable user: $e');
    }
  }

  Future<void> _changePassword(String username) async {
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => _ChangePasswordDialog(username: username),
    );
    if (password == null) return;

    try {
      await widget.reliquary.changePassword(username, password);
      if (!mounted) return;
      _showSnackBar('Password changed');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to change password: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<Map<String, dynamic>>? _filteredUsersCache;
  String? _cachedQuery;
  List<Map<String, dynamic>>? _cachedUsers;

  List<Map<String, dynamic>> get _filteredUsers {
    if (_cachedQuery == _query && _cachedUsers == _users) {
      return _filteredUsersCache ?? _users;
    }
    _cachedQuery = _query;
    _cachedUsers = _users;
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      _filteredUsersCache = _users;
    } else {
      _filteredUsersCache = _users.where((user) {
        final username = (user['username'] as String?) ?? '';
        final role = (user['role'] as String?) ?? '';
        return username.toLowerCase().contains(normalizedQuery) ||
            role.toLowerCase().contains(normalizedQuery);
      }).toList();
    }
    return _filteredUsersCache!;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: isDesktop ? null : AppBar(title: const Text('User Management')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isDesktop
          ? _buildDesktop()
          : _buildMobile(),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton(
              onPressed: _createUser,
              child: const Icon(Icons.person_add),
            ),
    );
  }

  Widget _buildMobile() {
    final users = _filteredUsers;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: users.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _SearchField(
              query: _query,
              onChanged: (value) => setState(() => _query = value),
            ),
          );
        }
        final user = users[index - 1];
        return _UserTile(
          key: ValueKey(user['username'] as String),
          user: user,
          onActivate: _activateUser,
          onChangePassword: _changePassword,
          onDelete: _deleteUser,
        );
      },
    );
  }

  Widget _buildDesktop() {
    final users = _filteredUsers;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage vault users and their access.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _createUser,
                icon: const Icon(Icons.person_add),
                label: const Text('ADD USER'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SearchField(
            query: _query,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          if (users.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No users found'),
              ),
            )
          else
            for (final user in users)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _UserTile(
                  key: ValueKey(user['username'] as String),
                  user: user,
                  onActivate: _activateUser,
                  onChangePassword: _changePassword,
                  onDelete: _deleteUser,
                ),
              ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: 'Search by name or role...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final void Function(String username) onActivate;
  final void Function(String username) onChangePassword;
  final void Function(Map<String, dynamic> user) onDelete;

  const _UserTile({
    super.key,
    required this.user,
    required this.onActivate,
    required this.onChangePassword,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final username = user['username'] as String;
    final role = user['role'] as String;
    final deactivated = user['deactivated'] == true;
    final isAdmin = role == 'admin';
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(
                username.isEmpty ? '?' : username.substring(0, 1).toUpperCase(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        username,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      _RoleChip(role: role),
                      if (deactivated) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text('Deactivated'),
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    isAdmin ? 'Administrator' : 'Standard user',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!isAdmin)
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'activate') onActivate(username);
                  if (action == 'password' && !deactivated) {
                    onChangePassword(username);
                  }
                  if (action == 'delete') onDelete(user);
                },
                itemBuilder: (_) => [
                  if (deactivated)
                    const PopupMenuItem(
                      value: 'activate',
                      child: Text('Re-enable'),
                    ),
                  if (!deactivated)
                    const PopupMenuItem(
                      value: 'password',
                      child: Text('Change password'),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      deactivated ? 'Delete permanently' : 'Deactivate',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    final colors = Theme.of(context).colorScheme;
    return Chip(
      label: Text(role.toUpperCase()),
      backgroundColor: isAdmin
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: isAdmin ? colors.onPrimaryContainer : colors.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _CreateUserResult {
  final String username;
  final String password;
  _CreateUserResult({required this.username, required this.password});
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final username = _usernameController.text.trim();
            final password = _passwordController.text;
            if (username.isEmpty || password.isEmpty) return;
            Navigator.pop(
              context,
              _CreateUserResult(username: username, password: password),
            );
          },
          child: const Text('Add User'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final String username;

  const _ChangePasswordDialog({required this.username});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Change Password for ${widget.username}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'New Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final password = _passwordController.text;
            final confirm = _confirmController.text;
            if (password.isEmpty || confirm.isEmpty) {
              setState(() => _error = 'Enter and confirm the new password.');
              return;
            }
            if (password != confirm) {
              setState(() => _error = 'Passwords do not match.');
              return;
            }
            Navigator.pop(context, password);
          },
          child: const Text('Update Password'),
        ),
      ],
    );
  }
}
