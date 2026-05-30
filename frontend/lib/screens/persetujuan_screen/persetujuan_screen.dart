import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/observation.dart';
import '../../models/user_profile.dart';
import '../../services/persetujuan_service.dart';
import '../../widgets/observation_card.dart';
import '../../utils/constants.dart';
import '../../providers/observation_provider.dart';
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Terjadi kesalahan:\n$_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_observations.isEmpty) {
      return Center(
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
