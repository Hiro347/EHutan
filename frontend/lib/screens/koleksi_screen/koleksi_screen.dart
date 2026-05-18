import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/observation.dart';
import '../../providers/connectivity_provider.dart';
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
    _tabController.addListener(() {gi
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
      // 1. Ambil draft lokal dari SQLite (termasuk yang belum sync)
      final localData = await SqliteService().getAllObservasi();
      final localObs = localData.map((e) => Observation.fromSQLite(e)).toList();
      final localIds = localObs.map((o) => o.id).toSet();

      // 2. Ambil data dari Supabase (observasi saya yang sudah sync)
      List<Observation> remoteObs = [];
      try {
        remoteObs = await _service.fetchObservasiSaya();
      } catch (_) {
        // Offline — lanjut pakai data lokal saja
      }

      // 3. Gabungkan: lokal lebih prioritas (mungkin ada update belum sync)
      final merged = <Observation>[...localObs];
      for (final obs in remoteObs) {
        if (!localIds.contains(obs.id)) {
          merged.add(obs);
        }
      }

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
          children: [
            _buildMyObservationsTab(),
            _buildUKFTab(),
          ],
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
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2, color: Color(0xFF1A2400)),
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
        tabs: const [Tab(text: 'Observasi Saya'), Tab(text: 'Observasi UKF')],
      ),
    );
  }

  Widget _buildMyObservationsTab() {
    if (_myLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_myError != null) return Center(child: Text(_myError!));
    if (_myObservations.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadMyObservations,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildMyStats(),
          ),
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
            child: Icon(Icons.travel_explore_rounded, size: 80, color: AppColors.primary.withValues(alpha: 0.7)),
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
    final verified = _myObservations.where((o) => o.statusApproval == 'TERVERIFIKASI').length;
    final pending = _myObservations.where((o) => o.statusApproval == 'MENUNGGU_VERIFIKASI').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          _simpleStatItem(Icons.nature_people_rounded, '${_myObservations.length} Total', Colors.blueGrey),
          const SizedBox(width: 8),
          _simpleStatItem(Icons.verified_rounded, '$verified Valid', Colors.green.shade600),
          const SizedBox(width: 8),
          _simpleStatItem(Icons.hourglass_empty_rounded, '$pending Pending', Colors.orange.shade700),
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
              child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUKFTab() {
    if (_ukfLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_ukfError != null) return Center(child: Text(_ukfError!));
    
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadUKFObservations(query: _searchQuery.isEmpty ? null : _searchQuery),
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
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          for (final entry in _ukfGrouped.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Text('DIVISI ${entry.key}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => SpeciesCard(
                    observation: entry.value[i],
                    onTap: () => showObservationDetailSheet(context, entry.value[i], () {}, widget.onFlyTo),
                  ),
                  childCount: entry.value.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12,
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