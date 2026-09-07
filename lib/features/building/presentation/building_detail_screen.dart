import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../models/building.dart';
import '../../../models/floor.dart';
import '../../../models/navigation_node.dart';
import '../../../services/repositories/building_repository.dart';
import '../../localization/presentation/localization_screen.dart';
import '../../qr/presentation/floor_qr_screen.dart';
import '../../registration/presentation/floor_registration_screen.dart';
import 'add_floor_screen.dart';

class BuildingDetailScreen extends StatefulWidget {
  final String buildingId;
  final BuildingRepository repository;

  const BuildingDetailScreen({
    super.key,
    required this.buildingId,
    required this.repository,
  });

  @override
  State<BuildingDetailScreen> createState() => _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends State<BuildingDetailScreen> {
  Building? _building;
  List<Floor> _floors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final b = await widget.repository.getBuildingById(widget.buildingId);
    final floors = await widget.repository.getFloorsForBuilding(widget.buildingId);

    if (mounted) {
      setState(() {
        _building = b;
        _floors = floors;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_building?.name ?? 'Building Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Floors',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () async {
                              final res = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => AddFloorScreen(
                                    buildingId: widget.buildingId,
                                    repository: widget.repository,
                                  ),
                                ),
                              );
                              if (res == true) {
                                _loadData();
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('ADD FLOOR'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_floors.isEmpty)
                        _buildEmptyFloorsCard()
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _floors.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildFloorCard(_floors[index]);
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_rounded, color: AppTheme.primaryCyan, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _building?.name ?? 'Building',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (_building?.address != null) ...[
            const SizedBox(height: 8),
            Text(
              _building!.address!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Floors: ${_floors.length}',
            style: const TextStyle(color: AppTheme.accentBlue, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFloorsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.layers_clear_outlined, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            const Text(
              'No floors registered.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add floors to begin walking registration.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final res = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AddFloorScreen(
                      buildingId: widget.buildingId,
                      repository: widget.repository,
                    ),
                  ),
                );
                if (res == true) {
                  _loadData();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('ADD FLOOR NOW'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFloorCard(Floor floor) {
    final bool isReady = floor.isReady;
    final bool isDraft = !isReady && floor.nodes.isNotEmpty;
    
    final Color statusColor = isReady
        ? Colors.greenAccent
        : (isDraft ? Colors.orangeAccent : Colors.amberAccent);

    final String statusText = isReady
        ? 'READY'
        : (isDraft ? 'DRAFT' : 'NOT REGISTERED');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'L${floor.floorNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryCyan,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          floor.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${floor.nodes.length} Nodes · ${floor.edges.length} Edges · ${floor.destinations.length} Destinations',
                          style: const TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => FloorRegistrationScreen(
                          buildingId: widget.buildingId,
                          floorId: floor.floorId,
                          floorName: floor.name,
                          repository: widget.repository,
                        ),
                      ),
                    );
                    if (res == true) {
                      _loadData();
                    }
                  },
                  icon: const Icon(Icons.directions_walk_rounded, size: 16),
                  label: Text(floor.nodes.isNotEmpty ? 'RE-REGISTER FLOOR' : 'REGISTER FLOOR', style: const TextStyle(fontSize: 12)),
                ),
                if (floor.nodes.isNotEmpty) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isReady ? Colors.green : Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: isReady
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LocalizationScreen(
                                  buildingId: widget.buildingId,
                                  floorId: floor.floorId,
                                  repository: widget.repository,
                                ),
                              ),
                            );
                          }
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Floor is DRAFT or invalid. Complete registration and validation first.'),
                              ),
                            );
                          },
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: Text(isReady ? 'START NAVIGATION' : 'NOT READY', style: const TextStyle(fontSize: 12)),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      _showRouteDataDialog(floor);
                    },
                    icon: const Icon(Icons.account_tree_rounded, size: 16),
                    label: const Text('VIEW ROUTE DATA', style: TextStyle(fontSize: 12)),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: const BorderSide(color: AppTheme.accentBlue),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FloorQrScreen(
                            buildingName: _building?.name ?? 'Building',
                            floor: floor,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppTheme.accentBlue),
                    label: const Text('GENERATE QR', style: TextStyle(fontSize: 12, color: AppTheme.accentBlue)),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _confirmDeleteFloor(floor),
                  tooltip: 'Delete Floor',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFloor(Floor floor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Floor?'),
        content: Text('Are you sure you want to delete "${floor.name}"? This action cannot be undone and will delete all registered nodes and destinations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repository.deleteFloor(widget.buildingId, floor.floorId);
      _loadData();
    }
  }

  void _showRouteDataDialog(Floor floor) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${floor.name} Route Data'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total Nodes: ${floor.nodes.length}'),
                Text('Total Edges: ${floor.edges.length}'),
                Text('Destinations: ${floor.destinations.map((d) => d.name).join(", ")}'),
                const SizedBox(height: 12),
                const Text('Nodes:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...floor.nodes.map((n) => Text('• ${n.name} (${n.type.nameString}) [${n.position.x.toStringAsFixed(1)}, ${n.position.y.toStringAsFixed(1)}, ${n.position.z.toStringAsFixed(1)}]')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }
}
