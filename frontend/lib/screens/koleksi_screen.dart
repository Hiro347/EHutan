import 'package:flutter/material.dart';
import '../models/observation.dart';
import '../services/koleksi_service.dart';
import '../services/sqlite_service.dart'; 
import '../widgets/species_card.dart';
import '../utils/constants.dart';
import 'observation_detail_sheet.dart';

class KoleksiScreen extends StatefulWidget {
  const KoleksiScreen({super.key});

  @override
  State<KoleksiScreen> createState() => _KoleksiScreenState();
}

class _KoleksiScreenState extends State<KoleksiScreen>
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
      // AMBIL DARI SQLITE (DRAFT LOKAL)
      final localData = await SqliteService().getAllObservasi();
      setState(() {
        _myObservations = localData.map((e) => Observation.fromSQLite(e)).toList();
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight - 12),
        child: _buildTabBar(),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8EDE0), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        tabs: const [Tab(text: 'Observasi Saya'), Tab(text: 'Observasi UKF')],
      ),
    );
  }

  Widget _buildMyObservationsTab() {
    if (_myLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_myError != null) return Center(child: Text(_myError!));
    if (_myObservations.isEmpty) {
      return const Center(child: Text('Belum ada observasi. Mulai lapor!'));
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadMyObservations,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.78,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _myObservations.length,
        itemBuilder: (_, i) => SpeciesCard(
          observation: _myObservations[i],
          onTap: () => showObservationDetailSheet(
            context, 
            _myObservations[i],
            () => _loadMyObservations(), // REFRESH SETELAH HAPUS
          ),
        ),
      ),
    );
  }

  Widget _buildUKFTab() {
    if (_ukfLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_ukfError != null) return Center(child: Text(_ukfError!));
    
    return CustomScrollView(
      slivers: [
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
                  onTap: () => showObservationDetailSheet(context, entry.value[i], () {}),
                ),
                childCount: entry.value.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 0.78, crossAxisSpacing: 12, mainAxisSpacing: 12,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}