import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../models/destination.dart';
import '../../../models/qr_payload.dart';
import '../../../services/repositories/building_repository.dart';
import 'navigation_screen.dart';

class DestinationSelectionScreen extends StatefulWidget {
  final String buildingId;
  final String floorId;
  final String buildingName;
  final String floorName;
  final BuildingRepository repository;
  final QRPayload? qrPayload;

  const DestinationSelectionScreen({
    super.key,
    required this.buildingId,
    required this.floorId,
    required this.buildingName,
    required this.floorName,
    required this.repository,
    this.qrPayload,
  });

  @override
  State<DestinationSelectionScreen> createState() => _DestinationSelectionScreenState();
}

class _DestinationSelectionScreenState extends State<DestinationSelectionScreen> {
  List<Destination> _allDestinations = [];
  List<Destination> _filteredDestinations = [];
  bool _isLoading = true;
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'ALL',
    'ROOM',
    'LAB',
    'OFFICE',
    'WASHROOM',
    'LIFT',
    'EXIT',
  ];

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    setState(() => _isLoading = true);
    final dests = await widget.repository.getDestinations(widget.buildingId, widget.floorId);
    if (mounted) {
      setState(() {
        _allDestinations = dests;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredDestinations = _allDestinations.where((d) {
        final matchesCategory = _selectedCategory == 'ALL' ||
            (d.category.toLowerCase().contains(_selectedCategory.toLowerCase()));
        final matchesSearch = _searchQuery.isEmpty ||
            d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            d.category.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.pin_drop_rounded;
    final catLower = category.toLowerCase();
    if (catLower.contains('lab')) return Icons.computer_rounded;
    if (catLower.contains('room')) return Icons.meeting_room_rounded;
    if (catLower.contains('office')) return Icons.work_rounded;
    if (catLower.contains('washroom') || catLower.contains('toilet') || catLower.contains('restroom')) {
      return Icons.wc_rounded;
    }
    if (catLower.contains('lift') || catLower.contains('elevator')) return Icons.elevator_rounded;
    if (catLower.contains('exit') || catLower.contains('door')) return Icons.door_front_door_rounded;
    return Icons.pin_drop_rounded;
  }

  void _confirmAndStartNavigation(Destination destination) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(destination.category),
                      color: AppTheme.primaryCyan,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'READY TO NAVIGATE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCyan,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          destination.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              _buildDetailRow('Building', widget.buildingName),
              _buildDetailRow('Floor', widget.floorName),
              _buildDetailRow('Category', destination.category),
              _buildDetailRow('Target Node', destination.nodeId),
              _buildDetailRow('Localization', '✓ Localized & Ready', isHighlight: true),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close bottom sheet
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NavigationScreen(
                              buildingId: widget.buildingId,
                              floorId: widget.floorId,
                              buildingName: widget.buildingName,
                              floorName: widget.floorName,
                              destination: destination,
                              repository: widget.repository,
                              qrPayload: widget.qrPayload,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('START NAVIGATION', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Colors.greenAccent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Destination: ${widget.floorName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildSearchAndFilters(),
                    const SizedBox(height: 16),
                    const Text(
                      'DESTINATIONS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _allDestinations.isEmpty
                          ? _buildEmptyStateCard()
                          : _filteredDestinations.isEmpty
                              ? _buildNoSearchResultsCard()
                              : ListView.builder(
                                  itemCount: _filteredDestinations.length,
                                  itemBuilder: (context, index) {
                                    final dest = _filteredDestinations[index];
                                    return _buildDestinationItem(dest);
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.buildingName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            widget.floorName,
            style: const TextStyle(fontSize: 13, color: AppTheme.primaryCyan, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (val) {
            _searchQuery = val;
            _applyFilters();
          },
          decoration: InputDecoration(
            hintText: 'Search destinations by name or category...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryCyan),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _searchQuery = '';
                      _applyFilters();
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.cardDark,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryCyan,
                  backgroundColor: AppTheme.cardDark,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = cat;
                        _applyFilters();
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationItem(Destination dest) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryCyan.withValues(alpha: 0.15),
          child: Icon(_getCategoryIcon(dest.category), color: AppTheme.primaryCyan),
        ),
        title: Text(
          dest.name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(top: 4, right: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                dest.category,
                style: const TextStyle(color: AppTheme.accentBlue, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              'Node: ${dest.nodeId}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryCyan, size: 16),
        onTap: () => _confirmAndStartNavigation(dest),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Center(
      child: SingleChildScrollView(
        child: Card(
          color: AppTheme.cardDark,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_rounded, size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                const Text(
                  'No Destinations Registered',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'No target destinations have been registered for ${widget.floorName} yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('GO BACK TO FLOOR DETAILS'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResultsCard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            'No destinations match "$_searchQuery"',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
