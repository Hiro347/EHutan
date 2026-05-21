import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login_screen/login_screen.dart';
import 'package:intl/intl.dart';

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

  Future<void> _deleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengguna'),
        content: const Text(
          'Yakin ingin menghapus pengguna ini? (Data profil akan dihapus)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('profiles').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengguna berhasil dihapus')),
        );
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
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

                return ListTile(
                  title: Text(user['nama_lengkap'] ?? 'Tanpa Nama'),
                  subtitle: Text(
                    '$roleText\nEmail: $email\nLogin: ${_timeAgo(user['last_login'])}',
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
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteUser(user['id']),
                        tooltip: 'Hapus',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Berhasil diperbarui')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
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
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
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
  ];

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Akun'),
        content: const Text(
          'Perhatian: Akun Anda akan otomatis ter-logout setelah menekan OK.',
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
      final authResponse = await supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        data: {'nama_lengkap': _nameCtrl.text.trim()},
      );

      if (authResponse.user != null) {
        final updateData = <String, dynamic>{'role': _selectedRole};
        if (_selectedRole == 'Kordinator_Divisi' && _selectedDivisi != null) {
          updateData['divisi_takson'] = _selectedDivisi;
        }

        await supabase
            .from('profiles')
            .update(updateData)
            .eq('id', authResponse.user!.id);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
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
