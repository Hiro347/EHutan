import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/observation.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/observation_provider.dart';
import '../../services/koleksi_service.dart';
import '../../services/sqlite_service.dart';
import '../../widgets/species_card.dart';
import '../../utils/constants.dart';
import 'observation_detail_sheet.dart';

class KoleksiScreen extends ConsumerStatefulWidget {
  final Function(Observation)? onFlyTo;
  const KoleksiScreen({super.key, this.onFlyTo});

  @override
  ConsumerState<KoleksiScreen> createState() => _KoleksiScreenState();
}

class _KoleksiScreenState extends ConsumerState<KoleksiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final KoleksiService _service = KoleksiService();

  List<Observation> _myObservations = [];
  bool _myLoading = true;
  String? _myError;

  Map<String, List<Observation>> _ukfGrouped = {};
  bool _ukfLoading = true;
  String? _ukfError;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyObservations();
    _loadUKFObservations();
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMyObservations() async {
    if (!mounted) return;
    setState(() {
      _myLoading = true;
      _myError = null;
    });
    try {
      // 1. Ambil draft lokal dari SQLite (termasuk yang belum sync) khusus untuk user yang sedang login
      final user = Supabase.instance.client.auth.currentUser;
      final localData = user != null
          ? await SqliteService().getObservasiByUser(user.id)
          : await SqliteService().getAllObservasi();
      final localObs = localData.map((e) => Observation.fromSQLite(e)).toList();
      final localIds = localObs.map((o) => o.id).toSet();

      // 2. Ambil data dari Supabase (observasi saya yang sudah sync)
      List<Observation> remoteObs = [];
      try {
        remoteObs = await _service.fetchObservasiSaya();
      } catch (_) {
        // Offline — lanjut pakai data lokal saja
      }

      // 3. Gabungkan: prioritaskan lokal jika belum sync, jika sudah sync gunakan remote (update dari server)
      final merged = <Observation>[];
      final remoteMap = {for (var o in remoteObs) o.id: o};

      for (final local in localObs) {
        if (local.isSynced && remoteMap.containsKey(local.id)) {
          // Jika sudah sync, data dari server (remote) lebih up to date (misal verifikasi admin)
          merged.add(remoteMap[local.id]!);
          remoteMap.remove(local.id);
        } else {
          // Jika belum sync (baru/edit lokal) ATAU tidak ada di server
          merged.add(local);
          remoteMap.remove(local.id);
        }
      }
      
      // Tambahkan sisa data remote yang tidak ada di lokal (misal beda device)
      merged.addAll(remoteMap.values);

      // Urutkan berdasarkan waktu pengamatan terbaru
      merged.sort((a, b) => b.waktuPengamatan.compareTo(a.waktuPengamatan));

      setState(() {
        _myObservations = merged;
        _myLoading = false;
      });
    } catch (e) {
      setState(() {
        _myError = e.toString();
        _myLoading = false;
      });
    }
  }

  Future<void> _loadUKFObservations({String? query}) async {
    setState(() {
      _ukfLoading = true;
      _ukfError = null;
    });
    try {
      final data = await _service.fetchObservasiUKFGrouped(searchQuery: query);
      setState(() {
        _ukfGrouped = data;
        _ukfLoading = false;
      });
    } catch (e) {
      setState(() {
        _ukfError = e.toString();
        _ukfLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_searchQuery == value) {
        _loadUKFObservations(query: value.isEmpty ? null : value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to global refresh trigger
    ref.listen<int>(refreshTriggerProvider, (previous, current) {
      _loadMyObservations();
      _loadUKFObservations(query: _searchQuery.isEmpty ? null : _searchQuery);
    });

    // Listen terhadap konektivitas
    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, current) {
      if (previous == null || previous.isLoading) return;
      final wasOnline = previous.value ?? true;
      final nowOnline = current.value ?? true;

      // Jika dari offline menjadi online, otomatis ambil ulang data
      if (!wasOnline && nowOnline) {
        _loadMyObservations();
        _loadUKFObservations(query: _searchQuery.isEmpty ? null : _searchQuery);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      body: NestedScrollView(
        headerSliverBuilder: (_, innerBoxIsScrolled) => [
          _buildAppBar(innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildMyObservationsTab(), _buildUKFTab()],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const _KoleksiGuideDialog(),
          );
        },
        backgroundColor: AppColors.primary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Text(
          '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: Colors.white,
      elevation: innerBoxIsScrolled ? 2 : 0,
      shadowColor: Colors.black12,
      title: const Text(
        'KOLEKSI',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: 2,
          color: Color(0xFF1A2400),
        ),
      ),
      centerTitle: true,
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        dividerColor: const Color(0xFFE8EDE0),
        tabs: const [
          Tab(text: 'Observasi Saya'),
          Tab(text: 'Observasi UKF'),
        ],
      ),
    );
  }

  Widget _buildMyObservationsTab() {
    if (_myLoading)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    if (_myError != null) return Center(child: Text(_myError!));
    if (_myObservations.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadMyObservations,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadMyObservations,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildMyStats()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => SpeciesCard(
                  observation: _myObservations[i],
                  onTap: () => showObservationDetailSheet(
                    context,
                    _myObservations[i],
                    () => _loadMyObservations(), // REFRESH SETELAH HAPUS
                    widget.onFlyTo,
                    true,  // isOwner = true (observasi milik sendiri)
                    () => _loadMyObservations(), // REFRESH SETELAH EDIT
                  ),
                ),
                childCount: _myObservations.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.travel_explore_rounded,
              size: 80,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Koleksi Masih Kosong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2400),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Jelajahi alam liar dan catat temuan flora maupun fauna pertamamu hari ini!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyStats() {
    final verified = _myObservations
        .where((o) => o.statusApproval == 'TERVERIFIKASI')
        .length;
    final pending = _myObservations
        .where((o) => o.statusApproval == 'MENUNGGU_VERIFIKASI')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          _simpleStatItem(
            Icons.nature_people_rounded,
            '${_myObservations.length} Total',
            Colors.blueGrey,
          ),
          const SizedBox(width: 8),
          _simpleStatItem(
            Icons.verified_rounded,
            '$verified Valid',
            Colors.green.shade600,
          ),
          const SizedBox(width: 8),
          _simpleStatItem(
            Icons.hourglass_empty_rounded,
            '$pending Pending',
            Colors.orange.shade700,
          ),
        ],
      ),
    );
  }

  Widget _simpleStatItem(IconData icon, String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUKFTab() {
    if (_ukfLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_ukfError != null) return Center(child: Text(_ukfError!));

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadUKFObservations(
        query: _searchQuery.isEmpty ? null : _searchQuery,
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Cari spesies...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          for (final entry in _ukfGrouped.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Text(
                  'DIVISI ${entry.key}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final obs = entry.value[i];
                    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                    final isOwnData = currentUserId != null && obs.idPetugas == currentUserId;
                    return SpeciesCard(
                      observation: obs,
                      isOwnData: isOwnData,
                      onTap: () => showObservationDetailSheet(
                        context,
                        obs,
                        () => _loadUKFObservations(
                          query: _searchQuery.isEmpty ? null : _searchQuery,
                        ),
                        widget.onFlyTo,
                      ),
                    );
                  },
                  childCount: entry.value.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _KoleksiGuideDialog extends StatefulWidget {
  const _KoleksiGuideDialog();

  @override
  State<_KoleksiGuideDialog> createState() => _KoleksiGuideDialogState();
}

class _KoleksiGuideDialogState extends State<_KoleksiGuideDialog> {
  int _currentPage = 0;
  final int _totalPages = 3;

  Widget _buildDotIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Panduan Koleksi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A2400),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20,
                ),
              ],
            ),
            const Divider(color: Color(0xFFE8EDE0), height: 24, thickness: 1),
            
            // Content
            SizedBox(
              height: 250,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildPageContent(_currentPage),
              ),
            ),
            
            const SizedBox(height: 16),
            _buildDotIndicator(),
            const SizedBox(height: 20),
            
            // Footer: Navigation Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Prev Button
                TextButton(
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    disabledForegroundColor: Colors.grey.shade300,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Sebelumnya', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                
                // Next / Finish Button
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _totalPages - 1) {
                      setState(() => _currentPage++);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 0,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _currentPage == _totalPages - 1 ? 'Selesai' : 'Berikutnya',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_currentPage < _totalPages - 1) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(int page) {
    switch (page) {
      case 0:
        return _buildTabGuidePage();
      case 1:
        return _buildFlipGuidePage();
      case 2:
        return _buildDetailGuidePage();
      default:
        return const SizedBox.shrink();
    }
  }

  // Page 1: Tab Guide (My Observations vs UKF Observations)
  Widget _buildTabGuidePage() {
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTabDemoBox('Observasi Saya', true),
            const SizedBox(width: 12),
            _buildTabDemoBox('Observasi UKF', false),
          ],
        ),
        const SizedBox(height: 20),
        _buildInfoText(
          'Observasi Saya',
          'Daftar pengamatan fauna yang diinput oleh akun Anda. Mencakup data draf lokal (disimpan luring di SQLite saat tidak bersinyal) maupun laporan yang sedang terkirim atau menunggu persetujuan.',
        ),
        const SizedBox(height: 12),
        _buildInfoText(
          'Observasi UKF',
          'Pangkalan data keanekaragaman fauna IPB Dramaga yang berisi seluruh laporan satwa dari anggota UKF yang telah disetujui (Approved) oleh koordinator divisi.',
        ),
      ],
    );
  }

  Widget _buildTabDemoBox(String title, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? AppColors.primary : const Color(0xFFE8EDE0),
          width: 1.5,
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: active ? AppColors.primary : Colors.grey.shade500,
        ),
      ),
    );
  }

  // Page 2: Flip Card Guide
  Widget _buildFlipGuidePage() {
    return Column(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMiniCardPreview('Bagian Depan', 'Ringkasan data satwa (Nama, Takson, Akurasi AI).', true),
            const SizedBox(width: 10),
            const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            _buildMiniCardPreview('Bagian Belakang', 'Detail pengamat (Nama pencatat & status sync).', false),
          ],
        ),
        const SizedBox(height: 16),
        const Icon(Icons.gesture_rounded, color: AppColors.primary, size: 32),
        const SizedBox(height: 8),
        const Text(
          'Geser Kartu untuk Membalik',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A2400)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            'Lakukan swipe/geser kartu satwa ke arah kiri atau kanan menggunakan jari untuk membalik dan melihat isi informasi di balik kartu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCardPreview(String label, String desc, bool isFront) {
    return Container(
      width: 90,
      height: 110,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isFront ? const Color(0xFFF9FBF6) : const Color(0xFFF5F7F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDE0)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isFront ? Icons.badge_outlined : Icons.person_search_rounded, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A2400)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(fontSize: 8, color: Colors.black54, height: 1.2),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Page 3: Detail Card Guide
  Widget _buildDetailGuidePage() {
    return Column(
      key: const ValueKey(2),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.15),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: const Column(
            children: [
              Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 36),
              SizedBox(height: 6),
              Text(
                'Kartu Satwa',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A2400)),
              ),
              Text(
                'Ketuk Detail',
                style: TextStyle(fontSize: 8, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ketuk Kartu untuk Detail Lengkap',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A2400)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Ketuk/tekan kartu spesies untuk memunculkan lembar detail. Menampilkan peta koordinat temuan, foto resolusi tinggi, detail takson, dan opsi edit/hapus laporan Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoText(String label, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A2400)),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}
