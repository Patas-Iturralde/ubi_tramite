import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

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
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final usersAsync = ref.watch(_usersStreamProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar usuarios'),
        backgroundColor: AppColors.secondaryColor,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por email, nombre o UID',
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
            ),
          ),
          // Lista de usuarios
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final list = users.where((u) {
                  if (_query.isEmpty) return true;
                  final query = _query.toLowerCase();
                  return (u.email ?? '').toLowerCase().contains(query) ||
                         (u.displayName ?? '').toLowerCase().contains(query) ||
                         u.uid.toLowerCase().contains(query);
                }).toList();
                
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _query.isEmpty ? 'No hay usuarios' : 'No se encontraron usuarios',
                          style: TextStyle(
                            fontSize: 18,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final u = list[i];
                    return _UserCard(
                      user: u,
                      onRoleChanged: (r) async {
                        await AuthService.updateUserRole(uid: u.uid, role: r);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Rol actualizado a: ${_getRoleName(r)}'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          // Invalidar provider para actualizar UI
                          ref.invalidate(userRoleProvider);
                        }
                      },
                      onNameChanged: (newName) async {
                        await AuthService.updateDisplayName(uid: u.uid, displayName: newName);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nombre actualizado correctamente'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      onDelete: () async {
                        final ok = await _confirmDelete(context, u);
                        if (!ok) return;
                        try {
                          await AuthService.deleteUserDoc(uid: u.uid);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Usuario eliminado correctamente'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al eliminar usuario: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error al cargar usuarios: $e'),
                  ],
                ),
              ),
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
            content: Text('¿Estás seguro de eliminar el registro de ${u.displayName ?? u.email ?? u.uid}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.premium:
        return 'Premium';
      case UserRole.advisor:
        return 'Asesor';
      case UserRole.standard:
        return 'Estándar';
    }
  }
}

class _UserCard extends StatefulWidget {
  final AppUser user;
  final Future<void> Function(UserRole) onRoleChanged;
  final Future<void> Function(String) onNameChanged;
  final Future<void> Function() onDelete;

  const _UserCard({
    required this.user,
    required this.onRoleChanged,
    required this.onNameChanged,
    required this.onDelete,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  late UserRole _currentRole;
  late String _currentName;
  bool _isUpdatingRole = false;
  bool _isUpdatingName = false;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.user.role;
    _currentName = widget.user.displayName ?? widget.user.email?.split('@')[0] ?? 'Usuario';
  }

  @override
  void didUpdateWidget(_UserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Actualizar cuando cambie el widget (datos actualizados desde Firestore)
    if (oldWidget.user.role != widget.user.role) {
      _currentRole = widget.user.role;
    }
    if (oldWidget.user.displayName != widget.user.displayName) {
      _currentName = widget.user.displayName ?? widget.user.email?.split('@')[0] ?? 'Usuario';
    }
  }

  Future<void> _updateRole(UserRole newRole) async {
    if (newRole == _currentRole || _isUpdatingRole) return;
    
    setState(() => _isUpdatingRole = true);
    try {
      await widget.onRoleChanged(newRole);
      if (mounted) {
        setState(() {
          _currentRole = newRole;
          _isUpdatingRole = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingRole = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar rol: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _updateName() async {
    if (_isUpdatingName) return;
    
    final newName = await _showNameDialog();
    if (newName == null || newName.trim().isEmpty || newName == _currentName) return;
    
    setState(() => _isUpdatingName = true);
    try {
      await widget.onNameChanged(newName.trim());
      if (mounted) {
        setState(() {
          _currentName = newName.trim();
          _isUpdatingName = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingName = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar nombre: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String?> _showNameDialog() async {
    final ctrl = TextEditingController(text: widget.user.displayName ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar nombre'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ingrese el nuevo nombre',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.premium:
        return Colors.amber;
      case UserRole.advisor:
        return Colors.blue;
      case UserRole.standard:
        return Colors.grey;
    }
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.premium:
        return 'Premium';
      case UserRole.advisor:
        return 'Asesor';
      case UserRole.standard:
        return 'Estándar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = _getRoleColor(_currentRole);
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: isDark ? Colors.grey[850] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con nombre y email
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                  child: Text(
                    _currentName.isNotEmpty ? _currentName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email ?? 'Sin email',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Badge de rol
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: roleColor, width: 1.5),
              ),
              child: Text(
                _getRoleName(_currentRole),
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Controles
            Row(
              children: [
                // Botón editar nombre
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUpdatingName ? null : _updateName,
                    icon: _isUpdatingName
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit, size: 18),
                    label: const Text('Editar nombre'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Dropdown de rol
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<UserRole>(
                      value: _currentRole,
                      isExpanded: true,
                      underline: const SizedBox(),
                      onChanged: _isUpdatingRole
                          ? null
                          : (r) {
                              if (r != null) _updateRole(r);
                            },
                      items: [
                        DropdownMenuItem(
                          value: UserRole.admin,
                          child: Row(
                            children: [
                              Icon(Icons.admin_panel_settings, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text('Administrador'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: UserRole.premium,
                          child: Row(
                            children: [
                              Icon(Icons.star, size: 18, color: Colors.amber),
                              const SizedBox(width: 8),
                              const Text('Premium'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: UserRole.advisor,
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text('Asesor'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: UserRole.standard,
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              const Text('Estándar'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botón eliminar
                IconButton(
                  onPressed: _isUpdatingRole || _isUpdatingName
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminar usuario'),
                              content: Text(
                                '¿Estás seguro de eliminar el registro de ${widget.user.displayName ?? widget.user.email ?? widget.user.uid}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await widget.onDelete();
                        }
                      },
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: 'Eliminar usuario',
                ),
              ],
            ),
            // Indicador de actualización
            if (_isUpdatingRole || _isUpdatingName)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUpdatingRole ? 'Actualizando rol...' : 'Actualizando nombre...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
