import 'package:flutter/material.dart';
import '../../../models/building.dart';
import '../../../services/repositories/building_repository.dart';
import 'add_floor_screen.dart';

class CreateBuildingScreen extends StatefulWidget {
  final BuildingRepository repository;

  const CreateBuildingScreen({super.key, required this.repository});

  @override
  State<CreateBuildingScreen> createState() => _CreateBuildingScreenState();
}

class _CreateBuildingScreenState extends State<CreateBuildingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final buildingId = 'building_${DateTime.now().millisecondsSinceEpoch}';
    final newBuilding = Building(
      buildingId: buildingId,
      name: _nameController.text.trim(),
      address: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null,
      floors: const [],
    );

    await widget.repository.saveBuilding(newBuilding);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Building "${newBuilding.name}" created!')),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AddFloorScreen(
          buildingId: buildingId,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Building'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Register New Building',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter building details to set up multi-floor indoor navigation.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Building Name *',
                    hintText: 'e.g. College Main Building',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business_rounded),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Building name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description / Address (Optional)',
                    hintText: 'e.g. Main Engineering Block',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_isSaving ? 'CREATING...' : 'CREATE BUILDING'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
