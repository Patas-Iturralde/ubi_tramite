import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';

final _usersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return AuthService.usersStream();
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_usersStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar usuarios'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por email o UID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final list = users.where((u) {
                  if (_query.isEmpty) return true;
                  return (u.email ?? '').toLowerCase().contains(_query) || u.uid.contains(_query);
                }).toList();
                if (list.isEmpty) {
                  return const Center(child: Text('Sin usuarios'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final u = list[i];
                    return _UserTile(user: u, onChanged: (r) async {
                      await AuthService.updateUserRole(uid: u.uid, role: r);
                    }, onRename: (newName) async {
                      await AuthService.updateDisplayName(uid: u.uid, displayName: newName);
                    }, onDelete: () async {
                      final ok = await _confirmDelete(context, u);
                      if (!ok) return;
                      await AuthService.deleteUserDoc(uid: u.uid);
                    });
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, AppUser u) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar usuario'),
            content: Text('¿Eliminar registro de ${u.email ?? u.uid}?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;
  }
}

class _UserTile extends StatefulWidget {
  final AppUser user;
  final Future<void> Function(UserRole) onChanged;
  final Future<void> Function(String displayName) onRename;
  final Future<void> Function() onDelete;
  const _UserTile({required this.user, required this.onChanged, required this.onRename, required this.onDelete});

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  late UserRole _role;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(
        widget.user.displayName ?? (widget.user.email ?? ''),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(widget.user.email ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Renombrar',
            icon: const Icon(Icons.edit),
            onPressed: _saving
                ? null
                : () async {
                    final name = await _promptName(context, initial: widget.user.displayName ?? '');
                    if (name == null || name.trim().isEmpty) return;
                    setState(() => _saving = true);
                    await widget.onRename(name.trim());
                    setState(() => _saving = false);
                  },
          ),
          DropdownButton<UserRole>(
            value: _role,
            onChanged: _saving
                ? null
                : (r) async {
                    if (r == null) return;
                    setState(() => _saving = true);
                    await widget.onChanged(r);
                    setState(() {
                      _role = r;
                      _saving = false;
                    });
                  },
            items: const [
              DropdownMenuItem(value: UserRole.admin, child: Text('admin')),
              DropdownMenuItem(value: UserRole.premium, child: Text('premium')),
              DropdownMenuItem(value: UserRole.advisor, child: Text('advisor')),
              DropdownMenuItem(value: UserRole.standard, child: Text('standard')),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Eliminar registro',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onDelete();
                    setState(() => _saving = false);
                  },
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<String?> _promptName(BuildContext context, {required String initial}) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar nombre'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
  }
}

