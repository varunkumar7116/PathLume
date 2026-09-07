import 'package:flutter/material.dart';
import '../../../models/floor.dart';
import '../../../services/repositories/building_repository.dart';

import '../../registration/presentation/floor_registration_screen.dart';

class AddFloorScreen extends StatefulWidget {
  final String buildingId;
  final BuildingRepository repository;

  const AddFloorScreen({
    super.key,
    required this.buildingId,
    required this.repository,
  });

  @override
  State<AddFloorScreen> createState() => _AddFloorScreenState();
}

class _AddFloorScreenState extends State<AddFloorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numController = TextEditingController(text: '0');
  final _nameController = TextEditingController(text: 'Ground Floor');
  bool _isSaving = false;

  @override
  void dispose() {
    _numController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final floorNumber = int.parse(_numController.text.trim());
    final floorId = 'floor_${widget.buildingId}_${DateTime.now().millisecondsSinceEpoch}';

    final newFloor = Floor(
      floorId: floorId,
      buildingId: widget.buildingId,
      floorNumber: floorNumber,
      name: _nameController.text.trim(),
    );

    await widget.repository.saveFloor(newFloor);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Floor "${newFloor.name}" created!')),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => FloorRegistrationScreen(
          buildingId: widget.buildingId,
          floorId: newFloor.floorId,
          floorName: newFloor.name,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Floor'),
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
                  'Add Building Floor',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Specify the floor number and name (e.g. 0 for Ground, 1 for 1st Floor, -1 for Basement).',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _numController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Floor Number *',
                    hintText: 'e.g. 0, 1, 2, -1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Floor number is required.';
                    }
                    if (int.tryParse(val.trim()) == null) {
                      return 'Enter a valid integer floor number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Floor Name *',
                    hintText: 'e.g. Ground Floor, First Floor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.layers_rounded),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Floor name is required.';
                    }
                    return null;
                  },
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
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(_isSaving ? 'STARTING...' : 'START FLOOR REGISTRATION'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
