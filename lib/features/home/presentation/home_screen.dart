import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../models/building.dart';
import '../../../models/qr_payload.dart';
import '../../../services/repositories/building_repository.dart';
import '../../../services/repositories/firebase_building_repository.dart';
import '../../ar/presentation/ar_test_screen.dart';
import '../../building/presentation/building_detail_screen.dart';
import '../../building/presentation/create_building_screen.dart';
import '../../localization/presentation/qr_scanner_screen.dart';
import '../../navigation/presentation/destination_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  final BuildingRepository? repository;

  const HomeScreen({super.key, this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final BuildingRepository _repository;
  List<Building> _buildings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseBuildingRepository();
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    setState(() {
      _isLoading = true;
    });

    final list = await _repository.getAllBuildings();

    if (mounted) {
      setState(() {
        _buildings = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _startNavigationFlow() async {
    final payload = await Navigator.of(context).push<QRPayload>(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(repository: _repository),
      ),
    );

    if (payload != null && mounted) {
      final building = await _repository.getBuildingById(payload.buildingId);
      final floor = await _repository.getFloorById(payload.buildingId, payload.floorId);

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DestinationSelectionScreen(
              buildingId: payload.buildingId,
              floorId: payload.floorId,
              buildingName: building?.name ?? payload.buildingId,
              floorName: floor?.name ?? payload.floorId,
              repository: _repository,
              qrPayload: payload,
            ),
          ),
        );
        _loadBuildings();
      }
    }
  }

  Future<void> _startRegisterBuildingFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateBuildingScreen(repository: _repository),
      ),
    );
    _loadBuildings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PATHLUME'),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ArTestScreen()),
              );
            },
            tooltip: 'Hardware AR Core Test',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBuildings,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),

                // Primary Action 1: REGISTER BUILDING
                _buildPrimaryCard(
                  title: 'REGISTER BUILDING',
                  subtitle: 'Create & map a new indoor building floor using AR Core',
                  icon: Icons.add_location_alt_rounded,
                  color: AppTheme.primaryCyan,
                  onTap: _startRegisterBuildingFlow,
                ),

                const SizedBox(height: 16),

                // Primary Action 2: NAVIGATE
                _buildPrimaryCard(
                  title: 'NAVIGATE',
                  subtitle: 'Scan floor QR code to locate yourself & navigate in 3D AR',
                  icon: Icons.explore_rounded,
                  color: Colors.greenAccent,
                  onTap: _startNavigationFlow,
                ),

                const SizedBox(height: 32),

                const Text(
                  'REGISTERED BUILDINGS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.primaryCyan,
                  ),
                ),
                const SizedBox(height: 12),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_buildings.isEmpty)
                  _buildEmptyBuildingsCard()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _buildings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final b = _buildings[index];
                      return _buildBuildingCard(b);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withValues(alpha: 0.1),
              border: Border.all(color: AppTheme.primaryCyan, width: 2),
            ),
            child: const Icon(
              Icons.view_in_ar_rounded,
              size: 44,
              color: AppTheme.primaryCyan,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'PATHLUME',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Indoor AR Navigation System',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.cardDark,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyBuildingsCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Icons.domain_disabled_rounded, size: 40, color: Colors.white38),
            SizedBox(height: 10),
            Text(
              'No registered buildings found.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 4),
            Text(
              'Tap "REGISTER BUILDING" above to begin indoor mapping.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingCard(Building building) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryCyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.business_rounded, color: AppTheme.primaryCyan),
        ),
        title: Text(
          building.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        subtitle: Text(
          '${building.floors.length} Floors ${building.address != null ? "· ${building.address}" : ""}',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.accentBlue),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BuildingDetailScreen(
                buildingId: building.buildingId,
                repository: _repository,
              ),
            ),
          );
          _loadBuildings();
        },
      ),
    );
  }
}
