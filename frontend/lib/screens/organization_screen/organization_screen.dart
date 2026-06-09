import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:intl/intl.dart';
import '../../utils/custom_toast.dart';

class OrganizationScreen extends StatefulWidget {
  const OrganizationScreen({super.key});

  @override
  State<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _supabase
          .from('profiles')
          .select(
            'id, nama_lengkap, email, role, divisi_takson, status_aktivitas, last_login, created_at',
          )
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _AddUserDialog(),
    ).then((_) => _fetchUsers());
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => _EditUserDialog(user: user),
    ).then((_) => _fetchUsers());
  }

  Future<void> _toggleUserStatus(String id, String name, bool currentStatus) async {
    if (id == _supabase.auth.currentUser?.id) {
      CustomToast.show(context, 'Anda tidak dapat menonaktifkan akun sendiri', isError: true);
      return;
    }
    final newStatus = !currentStatus;
    final actionText = newStatus ? 'mengaktifkan' : 'menonaktifkan';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${newStatus ? 'Aktifkan' : 'Nonaktifkan'} Pengguna'),
        content: Text(
          'Yakin ingin $actionText pengguna "$name"?\n\n'
          '${newStatus ? "Pengguna akan dapat login dan menggunakan aplikasi kembali." : "Pengguna tidak akan bisa login atau mengakses aplikasi."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              newStatus ? 'Aktifkan' : 'Nonaktifkan',
              style: TextStyle(color: newStatus ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('profiles').update({'status_aktivitas': newStatus}).eq('id', id);
      if (mounted) {
        CustomToast.show(
          context, 
          'Pengguna berhasil ${newStatus ? 'diaktifkan' : 'dinonaktifkan'}'
        );
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal memproses: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteUserPermanently(String id, String name) async {
    if (id == _supabase.auth.currentUser?.id) {
      CustomToast.show(context, 'Anda tidak dapat menghapus akun sendiri', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus Permanen Pengguna',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Yakin ingin menghapus pengguna "$name" secara permanen?\n\n'
          'Peringatan: Tindakan ini tidak dapat dibatalkan. Seluruh data berikut akan terhapus selamanya:\n'
          '- Akun login pengguna\n'
          '- Profil pengguna\n'
          '- SEMUA data observasi yang dikirim oleh pengguna ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus Permanen',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('profiles').delete().eq('id', id);
      if (mounted) {
        CustomToast.show(context, 'Pengguna dan seluruh data terkait berhasil dihapus permanen');
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal menghapus: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  String _timeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds} detik yang lalu';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} menit yang lalu';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} jam yang lalu';
      } else if (difference.inDays < 30) {
        return '${difference.inDays} hari yang lalu';
      } else {
        return DateFormat('dd-MM-yyyy HH:mm').format(date);
      }
    } catch (e) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengguna'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchUsers),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final user = _users[index];
                final role = user['role']?.toString().replaceAll('_', ' ') ?? '-';
                final email = user['email'] ?? 'Email belum sinkron';
                final divisi = user['divisi_takson'] ?? '';
                final roleText = divisi.isNotEmpty ? '$role ($divisi)' : role;

                final isActive = user['status_aktivitas'] ?? true;
                return ListTile(
                  title: Text.rich(
                    TextSpan(
                      text: user['nama_lengkap'] ?? 'Tanpa Nama',
                      style: TextStyle(
                        color: isActive ? Colors.black : Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        decoration: isActive ? null : TextDecoration.lineThrough,
                      ),
                      children: [
                        if (!isActive)
                          const TextSpan(
                            text: ' (Nonaktif)',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              decoration: TextDecoration.none,
                            ),
                          ),
                      ],
                    ),
                  ),
                  subtitle: Text(
                    '$roleText\nEmail: $email\nLogin: ${_timeAgo(user['last_login'])}',
                    style: TextStyle(
                      color: isActive ? Colors.black87 : Colors.grey.shade400,
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditUserDialog(user),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: Icon(
                          isActive
                              ? Icons.block_flipped
                              : Icons.check_circle_outline_rounded,
                          color: isActive ? Colors.orange : Colors.green,
                        ),
                        onPressed: () => _toggleUserStatus(
                          user['id'],
                          user['nama_lengkap'] ?? '',
                          isActive,
                        ),
                        tooltip: isActive ? 'Nonaktifkan' : 'Aktifkan',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                        onPressed: () => _deleteUserPermanently(
                          user['id'],
                          user['nama_lengkap'] ?? '',
                        ),
                        tooltip: 'Hapus Permanen',
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  const _EditUserDialog({required this.user});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  final _passwordCtrl = TextEditingController();
  late String _selectedRole;
  String? _selectedDivisi;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late bool _statusAktivitas;

  final List<String> _roles = [
    'Petugas_Lapangan',
    'Kordinator_Divisi',
    'Admin',
  ];
  final List<String> _divisi = [
    'DK Karnivora',
    'DK Herbivora',
    'DK Primata',
    'DK Burung',
    'DK Reptil Amfibi',
    'DK Insekta',
    'DK Fauna Perairan',
    'DK Eksitu',
    'DK Flora',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user['nama_lengkap']);
    _selectedRole = widget.user['role'] ?? 'Petugas_Lapangan';
    _selectedDivisi = widget.user['divisi_takson'];
    if (_selectedRole != 'Kordinator_Divisi') {
      _selectedDivisi = null;
    }
    _statusAktivitas = widget.user['status_aktivitas'] ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Update password jika diisi
      if (_passwordCtrl.text.isNotEmpty) {
        // PERHATIAN: Memperbarui password user lain membutuhkan izin admin (Service Role).
        // Fungsi admin.updateUserById mungkin gagal jika dipanggil dari aplikasi (anon key).
        await supabase.auth.admin.updateUserById(
          widget.user['id'],
          attributes: AdminUserAttributes(password: _passwordCtrl.text),
        );
      }

      // Update profil
      final updateData = <String, dynamic>{
        'nama_lengkap': _nameCtrl.text.trim(),
        'role': _selectedRole,
        'status_aktivitas': _statusAktivitas,
      };

      if (_selectedRole == 'Kordinator_Divisi' && _selectedDivisi != null) {
        updateData['divisi_takson'] = _selectedDivisi;
      } else {
        updateData['divisi_takson'] = null; // Clear if role changed
      }

      await supabase
          .from('profiles')
          .update(updateData)
          .eq('id', widget.user['id']);

      if (mounted) {
        Navigator.pop(context);
        CustomToast.show(context, 'Berhasil diperbarui');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Pengguna'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  hintText: 'Maks 20 karakter',
                ),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedRole = v!;
                    if (v != 'Kordinator_Divisi') _selectedDivisi = null;
                  });
                },
              ),
              if (_selectedRole == 'Kordinator_Divisi')
                DropdownButtonFormField<String>(
                  value: _selectedDivisi,
                  decoration: const InputDecoration(labelText: 'Divisi'),
                  items: _divisi
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDivisi = v),
                ),
              const Divider(height: 24),
              const Text(
                'Ubah Password (opsional)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              TextFormField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (v) =>
                    v!.isNotEmpty && v.length < 6 ? 'Minimal 6 karakter' : null,
              ),
              const Divider(height: 24),
              SwitchListTile(
                title: const Text('Status Aktivitas'),
                subtitle: Text(
                  _statusAktivitas ? 'Aktif' : 'Nonaktif (Tidak bisa login)',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _statusAktivitas,
                activeThumbColor: const Color(0xFF0D5C1E),
                activeTrackColor: const Color(0xFF0D5C1E).withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() {
                    _statusAktivitas = val;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _updateUser,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  String _selectedRole = 'Petugas_Lapangan';
  String? _selectedDivisi;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final List<String> _roles = [
    'Petugas_Lapangan',
    'Kordinator_Divisi',
    'Admin',
  ];
  final List<String> _divisi = [
    'DK Karnivora',
    'DK Herbivora',
    'DK Primata',
    'DK Burung',
    'DK Reptil Amfibi',
    'DK Insekta',
    'DK Fauna Perairan',
    'DK Eksitu',
    'DK Flora',
  ];

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Akun'),
        content: const Text(
          'Yakin ingin membuat akun pengguna baru ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.functions.invoke(
        'create-user',
        body: {
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'nama_lengkap': _nameCtrl.text.trim(),
          'role': _selectedRole,
          'divisi_takson': _selectedDivisi,
        },
      );

      if (mounted) {
        Navigator.pop(context); // Menutup dialog tambah user
        CustomToast.show(context, 'Akun berhasil dibuat!');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Pengguna Baru'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  hintText: 'Maks 20 karakter',
                ),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedRole = v!;
                    if (v != 'Kordinator_Divisi') _selectedDivisi = null;
                  });
                },
              ),
              if (_selectedRole == 'Kordinator_Divisi')
                DropdownButtonFormField<String>(
                  value: _selectedDivisi,
                  decoration: const InputDecoration(labelText: 'Divisi'),
                  items: _divisi
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDivisi = v),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _createUser,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
