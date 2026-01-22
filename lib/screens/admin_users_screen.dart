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
  UserRole? _selectedRoleFilter;

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
          // Barra de búsqueda y filtros
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
            child: Column(
              children: [
                TextField(
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
                const SizedBox(height: 12),
                // Filtros por rol
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        'Todos',
                        _selectedRoleFilter == null,
                        isDark,
                        onTap: () => setState(() => _selectedRoleFilter = null),
                      ),
                      const SizedBox(width: 8),
                      ...UserRole.values.map((role) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          _getRoleName(role),
                          _selectedRoleFilter == role,
                          isDark,
                          color: _getRoleColor(role),
                          onTap: () => setState(() => _selectedRoleFilter = role),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Lista de usuarios
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final filteredUsers = users.where((u) {
                  if (_selectedRoleFilter != null && u.role != _selectedRoleFilter) {
                    return false;
                  }
                  if (_query.isEmpty) return true;
                  final query = _query.toLowerCase();
                  return (u.email ?? '').toLowerCase().contains(query) ||
                         (u.displayName ?? '').toLowerCase().contains(query) ||
                         u.uid.toLowerCase().contains(query);
                }).toList();

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: isDark ? Colors.grey[850] : Colors.grey[50],
                      child: Row(
                        children: [
                          Icon(Icons.people, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Total: ${users.length} usuarios',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                          const Spacer(),
                          if (_selectedRoleFilter != null || _query.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _query = '';
                                  _selectedRoleFilter = null;
                                });
                              },
                              icon: const Icon(Icons.clear_all, size: 16),
                              label: const Text('Limpiar filtros'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Lista de usuarios
                    Expanded(
                    child: filteredUsers.isEmpty
                        ? Center(
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
                                  _query.isEmpty && _selectedRoleFilter == null
                                      ? 'No hay usuarios'
                                      : 'No se encontraron usuarios',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredUsers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final u = filteredUsers[i];
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
                          ),
                  ),
                ],
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

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    bool isDark, {
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppColors.primaryColor).withOpacity(0.2)
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? AppColors.primaryColor)
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? (color ?? AppColors.primaryColor)
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
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

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.premium:
        return Icons.star;
      case UserRole.advisor:
        return Icons.person_outline;
      case UserRole.standard:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = _getRoleColor(_currentRole);
    
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      color: isDark ? Colors.grey[850] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con información del usuario
            Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        roleColor,
                        roleColor.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _currentName.isNotEmpty ? _currentName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Información del usuario
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currentName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Badge de rol
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: roleColor, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getRoleIcon(_currentRole),
                                  size: 14,
                                  color: roleColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getRoleName(_currentRole),
                                  style: TextStyle(
                                    color: roleColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email ?? 'Sin email',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Controles de acción
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
                    label: const Text('Nombre'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                      icon: _isUpdatingRole
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_drop_down),
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
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(roleColor),
                      ),
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
