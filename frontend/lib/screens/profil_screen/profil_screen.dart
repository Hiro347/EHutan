// lib/screens/profil_screen/profil_screen.dart
//
// Layar Profil — user dapat melihat & mengedit nama dan foto profilnya.
// Menggunakan Riverpod (profileProvider) agar UI rebuild otomatis setelah update.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/profile_provider.dart';
import '../../utils/constants.dart';
import '../login_screen/login_screen.dart';
import '../organization_screen/organization_screen.dart';
import '../../providers/observation_provider.dart';

class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.statusRevisi,
              ),
              const SizedBox(height: 12),
              Text('Gagal memuat profil\n$e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(profileProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (profile) => _ProfilContent(profile: profile),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget konten utama (ditampilkan saat data sudah tersedia)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfilContent extends ConsumerStatefulWidget {
  final EditableProfile profile;
  const _ProfilContent({required this.profile});

  @override
  ConsumerState<_ProfilContent> createState() => _ProfilContentState();
}

class _ProfilContentState extends ConsumerState<_ProfilContent> {
  late final TextEditingController _nameCtrl;
  bool _isEditingName = false;
  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.fullName ?? '');
  }

  @override
  void didUpdateWidget(_ProfilContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Saat profil berhasil diupdate, refresh controller
    if (oldWidget.profile.fullName != widget.profile.fullName &&
        !_isEditingName) {
      _nameCtrl.text = widget.profile.fullName ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Simpan nama baru ─────────────────────────────────────────────────────
  Future<void> _saveName() async {
    final trimmed = _nameCtrl.text.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nama tidak boleh kosong')));
      return;
    }
    setState(() => _isSavingName = true);
    try {
      await ref.read(profileProvider.notifier).updateFullName(trimmed);
      if (mounted) {
        setState(() => _isEditingName = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nama berhasil diperbarui ✅'),
            backgroundColor: AppColors.statusTerverifikasi,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppColors.statusRevisi,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  // ── Bottom sheet pilih sumber foto ──────────────────────────────────────
  void _showAvatarSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Ganti Foto Profil',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF0D5C1E),
                  ),
                ),
                title: const Text('Ambil dari Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _doUpdateAvatar(fromCamera: true);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF1565C0),
                  ),
                ),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _doUpdateAvatar(fromCamera: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doUpdateAvatar({required bool fromCamera}) async {
    try {
      await ref
          .read(profileProvider.notifier)
          .updateAvatar(fromCamera: fromCamera);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui 🎉'),
            backgroundColor: AppColors.statusTerverifikasi,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload foto: $e'),
            backgroundColor: AppColors.statusRevisi,
          ),
        );
      }
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar'),
        content: const Text('Apakah kamu yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      // Invalidate providers to clear cache of the logged-out user
      ref.invalidate(profileProvider);
      ref.invalidate(localObservationProvider);
      ref.invalidate(unsyncedCountProvider);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final profileAsync = ref.watch(profileProvider);
    final isUpdating = profileAsync.isLoading;

    return CustomScrollView(
      slivers: [
        // ── AppBar dengan hero foto ─────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: const Color(0xFF0D5C1E),
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              children: [
                // Gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF062A0E), Color(0xFF0D5C1E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Decorative circles
                Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -20,
                  left: -30,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),
                // Avatar di tengah
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: isUpdating ? null : _showAvatarSourceSheet,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            _AvatarWidget(
                              avatarUrl: profile.avatarUrl,
                              radius: 52,
                            ),
                            if (!isUpdating)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1FB840),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            if (isUpdating)
                              const Positioned.fill(
                                child: CircleAvatar(
                                  radius: 52,
                                  backgroundColor: Colors.black26,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Kartu Info Akun ───────────────────────────────────────
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        title: 'Informasi Akun',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 16),

                      // Email (readonly)
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: profile.email.isNotEmpty ? profile.email : '-',
                      ),
                      const Divider(height: 24),

                      // Role (readonly)
                      _InfoRow(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Jabatan',
                        value: _formatRole(profile.role),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Kartu Edit Nama ───────────────────────────────────────
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        title: 'Nama Lengkap',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      if (_isEditingName) ...[
                        TextField(
                          controller: _nameCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Masukkan nama lengkap...',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.edit_rounded,
                              size: 18,
                            ),
                          ),
                          onSubmitted: (_) => _saveName(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => setState(() {
                                _isEditingName = false;
                                _nameCtrl.text = profile.fullName ?? '';
                              }),
                              child: const Text('Batal'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _isSavingName ? null : _saveName,
                              icon: _isSavingName
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check, size: 18),
                              label: const Text('Simpan'),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                profile.fullName?.isNotEmpty == true
                                    ? profile.fullName!
                                    : 'Belum diisi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: profile.fullName?.isNotEmpty == true
                                      ? const Color(0xFF062A0E)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setState(() => _isEditingName = true),
                              icon: const Icon(Icons.edit_rounded, size: 20),
                              color: AppColors.primary,
                              tooltip: 'Ubah nama',
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Kartu Ubah Foto ───────────────────────────────────────
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        title: 'Foto Profil',
                        icon: Icons.photo_camera_outlined,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: isUpdating ? null : _showAvatarSourceSheet,
                        icon: const Icon(Icons.upload_rounded),
                        label: const Text('Ganti Foto Profil'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '💡 Foto akan dipotong otomatis menjadi bentuk persegi',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                
                if (profile.role == 'Admin') ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          title: 'Administrasi',
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OrganizationScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.business_rounded),
                          label: const Text('Kelola Organisasi & Pengguna'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '💡 Akses khusus admin untuk menambah & mengatur akun',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),

                // ── Tombol Logout ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Keluar dari Akun'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatRole(String? role) {
    switch (role) {
      case 'Petugas_Lapangan':
        return 'Petugas Lapangan';
      case 'Kordinator_Divisi':
        return 'Kordinator Divisi';
      case 'Admin':
        return 'Admin';
      default:
        return role ?? '-';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  const _AvatarWidget({this.avatarUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                const CircularProgressIndicator(strokeWidth: 2),
            errorWidget: (_, __, ___) => _PlaceholderAvatar(radius: radius),
          ),
        ),
      );
    }
    return _PlaceholderAvatar(radius: radius);
  }
}

class _PlaceholderAvatar extends StatelessWidget {
  final double radius;
  const _PlaceholderAvatar({required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF0D5C1E),
      child: Icon(Icons.person_rounded, size: radius, color: Colors.white70),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.5,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF062A0E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
