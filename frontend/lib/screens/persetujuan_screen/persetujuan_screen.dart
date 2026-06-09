import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/observation.dart';
import '../../models/user_profile.dart';
import '../../services/persetujuan_service.dart';
import '../../widgets/observation_card.dart';
import '../../utils/constants.dart';
import '../../providers/observation_provider.dart';
import '../../providers/connectivity_provider.dart';
import 'persetujuan_detail_sheet.dart';

class PersetujuanScreen extends ConsumerStatefulWidget {
  const PersetujuanScreen({super.key});

  @override
  ConsumerState<PersetujuanScreen> createState() => _PersetujuanScreenState();
}

class _PersetujuanScreenState extends ConsumerState<PersetujuanScreen> {
  final PersetujuanService _service = PersetujuanService();

  UserProfile? _userProfile;
  List<Observation> _observations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _service.fetchCurrentUserProfile();
      if (profile == null) {
        setState(() {
          _error = 'Gagal memuat profil pengguna';
          _isLoading = false;
        });
        return;
      }

      _userProfile = profile;
      List<Observation> obs = [];

      if (profile.isPetugasLapangan) {
        obs = await _service.fetchPersetujuanPetugas(profile.id);
      } else {
        obs = await _service.fetchMenungguVerifikasi(
          isAdmin: profile.isAdmin,
          divisi: profile.divisiTakson,
        );
      }

      setState(() {
        _observations = obs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(refreshTriggerProvider, (previous, current) {
      _loadData();
    });

    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, current) {
      if (previous == null || previous.isLoading) return;
      final wasOnline = previous.value ?? true;
      final nowOnline = current.value ?? true;

      // Jika dari offline menjadi online, otomatis ambil ulang data
      if (!wasOnline && nowOnline) {
        _loadData();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      appBar: AppBar(
        title: const Text(
          'Persetujuan',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
            color: Color(0xFF1A2400),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      final isOffline = _error!.contains('SocketException') ||
          _error!.contains('NetworkImage') ||
          _error!.contains('ClientException') ||
          _error!.contains('host');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                isOffline ? 'Koneksi Terputus' : 'Terjadi Kesalahan',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2400),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOffline
                    ? 'Halaman persetujuan memerlukan koneksi internet untuk memuat data dari server. Silakan hubungkan perangkat Anda ke internet lalu coba lagi.'
                    : 'Gagal memuat data: $_error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_observations.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _userProfile!.isPetugasLapangan
                          ? 'Belum ada data observasi yang diajukan.'
                          : 'Tidak ada observasi yang menunggu verifikasi.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _observations.length,
        itemBuilder: (context, index) {
          final obs = _observations[index];
          return ObservationCard(
            obs: obs,
            isSelected: false,
            onTap: () {
              showPersetujuanDetailSheet(
                context: context,
                observation: obs,
                userProfile: _userProfile!,
                onRefresh: _loadData,
              );
            },
          );
        },
      ),
    );
  }
}
