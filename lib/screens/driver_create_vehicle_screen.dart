import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color kScreenTeal = Color(0xFFE0F9FB);
const Color kUniRideTeal2 = Color(0xFF009DAE);
const Color kUniRideYellow = Color(0xFFFFC727);

class DriverCreateVehicleScreen extends StatefulWidget {
  final String? vehicleId;
  final Map<String, dynamic>? initialData;

  const DriverCreateVehicleScreen({
    super.key,
    this.vehicleId,
    this.initialData,
  });

  @override
  State<DriverCreateVehicleScreen> createState() => _DriverCreateVehicleScreenState();
}

class _DriverCreateVehicleScreenState extends State<DriverCreateVehicleScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _makeController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _colorController;
  late TextEditingController _licensePlateController;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _makeController = TextEditingController(text: widget.initialData?['make'] ?? '');
    _modelController = TextEditingController(text: widget.initialData?['model'] ?? '');
    _yearController = TextEditingController(text: widget.initialData?['year']?.toString() ?? '');
    _colorController = TextEditingController(text: widget.initialData?['color'] ?? '');
    _licensePlateController = TextEditingController(text: widget.initialData?['licensePlate'] ?? '');
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) {
      _showMessage("Please log in to save a vehicle");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final vehicleData = {
        'userId': user.uid,
        'make': _makeController.text.trim(),
        'model': _modelController.text.trim(),
        'year': int.tryParse(_yearController.text) ?? 0,
        'color': _colorController.text.trim(),
        'licensePlate': _licensePlateController.text.trim().toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.vehicleId != null) {
        // Update existing vehicle
        await _firestore
            .collection('vehicles')
            .doc(widget.vehicleId)
            .update(vehicleData);
        
        _showMessage("Vehicle updated successfully");
      } else {
        // Create new vehicle
        await _firestore.collection('vehicles').add(vehicleData);
        
        _showMessage("Vehicle created successfully");
      }

      setState(() => _isSaving = false);

      if (mounted) Navigator.pop(context);
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      setState(() => _isSaving = false);
      _showMessage("Error saving vehicle: $e");
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.vehicleId != null;

    return Scaffold(
      backgroundColor: kScreenTeal,
      appBar: AppBar(
        backgroundColor: kScreenTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kUniRideTeal2),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? "Edit Vehicle" : "Add Vehicle",
          style: const TextStyle(
            color: kUniRideTeal2,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Vehicle Information",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Make
              TextFormField(
                controller: _makeController,
                decoration: InputDecoration(
                  labelText: "Make (e.g., Toyota, Honda, BMW)",
                  labelStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.directions_car, color: kUniRideTeal2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kUniRideTeal2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kUniRideTeal2, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter the vehicle make";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Model
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: "Model (e.g., Corolla, Civic, X5)",
                  labelStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.directions_car, color: kUniRideTeal2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kUniRideTeal2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kUniRideTeal2, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter the vehicle model";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Year
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Year (e.g., 2023)",
                  labelStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.calendar_today, color: kUniRideTeal2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kUniRideTeal2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kUniRideTeal2, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter the vehicle year";
                  }
                  final year = int.tryParse(value);
                  if (year == null || year < 1900 || year > 2100) {
                    return "Please enter a valid year";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Color
              TextFormField(
                controller: _colorController,
                decoration: InputDecoration(
                  labelText: "Color (e.g., Black, White, Blue)",
                  labelStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.palette, color: kUniRideTeal2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kUniRideTeal2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kUniRideTeal2, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter the vehicle color";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // License Plate
              TextFormField(
                controller: _licensePlateController,
                decoration: InputDecoration(
                  labelText: "License Plate",
                  labelStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.confirmation_number, color: kUniRideTeal2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kUniRideTeal2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kUniRideTeal2, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter the license plate";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveVehicle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kUniRideYellow,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                          ),
                        )
                      : Text(
                          isEditing ? "Update Vehicle" : "Create Vehicle",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
