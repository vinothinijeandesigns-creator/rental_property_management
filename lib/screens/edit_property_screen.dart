import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/app_snackbar.dart';

class EditPropertyScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const EditPropertyScreen({super.key, required this.property});

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  late String _propertyNo;
  late String _propertyType;
  late String _ebMeterNumber;
  late String _waterCharge;
  late String _maintenanceResponsibility;
  late String _flatMaintenanceAmount;
  late String _maintenanceFrequency;

  final List<String> _propertyTypes = ['House', 'Shop', 'Flat', 'Warehouse'];
  final List<String> _maintenanceResponsibilities = ['Owner', 'Tenant'];
  final List<String> _maintenanceFrequencies = ['1 Month', '3 Months', '6 Months', '12 Months'];

  @override
  void initState() {
    super.initState();
    _propertyNo = widget.property['property_no']?.toString() ?? '';
    _propertyType = widget.property['property_type']?.toString() ?? 'House';
    _ebMeterNumber = widget.property['eb_meter_number']?.toString() ?? '';
    _waterCharge = widget.property['water_charge']?.toString() ?? '';
    _maintenanceResponsibility = widget.property['maintenance_responsibility']?.toString() ?? 'Owner';
    _flatMaintenanceAmount = widget.property['flat_maintenance_amount']?.toString() ?? '';
    _maintenanceFrequency = widget.property['maintenance_frequency']?.toString() ?? '1 Month';
    
    if (!_propertyTypes.contains(_propertyType)) _propertyType = 'House';
    if (!_maintenanceResponsibilities.contains(_maintenanceResponsibility)) _maintenanceResponsibility = 'Owner';
    if (!_maintenanceFrequencies.contains(_maintenanceFrequency)) _maintenanceFrequency = '1 Month';
  }

  Future<void> _updateProperty() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      await _supabaseService.updateProperty(widget.property['id'].toString(), {
        'property_no': _propertyNo,
        'property_type': _propertyType,
        'eb_meter_number': _ebMeterNumber,
        'water_charge': _waterCharge,
        'maintenance_responsibility': _maintenanceResponsibility,
        'flat_maintenance_amount': double.tryParse(_flatMaintenanceAmount),
        'maintenance_frequency': _maintenanceFrequency,
      });

      if (mounted) {
        AppSnackBar.showSuccess(context, 'Property updated successfully!');
        Navigator.pop(context, true); // Return true to indicate success and trigger reload
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to update property: ${AppSnackBar.cleanErrorMessage(e)}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Edit Property', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        label: 'Property No / Name',
                        initialValue: _propertyNo,
                        hint: 'e.g., Shop 01',
                        icon: Icons.tag,
                        onSaved: (value) => _propertyNo = value!,
                        validator: (value) => value == null || value.isEmpty ? 'Required field' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Property Type',
                        value: _propertyType,
                        items: _propertyTypes,
                        icon: Icons.home_work,
                        onChanged: (val) => setState(() => _propertyType = val!),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'EB Meter Number',
                        initialValue: _ebMeterNumber,
                        hint: 'e.g., 123-456-789',
                        icon: Icons.electric_meter,
                        onSaved: (value) => _ebMeterNumber = value ?? '',
                        validator: (value) => null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Water Charge (₹)',
                        initialValue: _waterCharge,
                        hint: 'e.g., 500 or Included',
                        icon: Icons.water_drop,
                        onSaved: (value) => _waterCharge = value ?? '',
                        validator: (value) => null,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Maintenance Responsibility',
                        value: _maintenanceResponsibility,
                        items: _maintenanceResponsibilities,
                        icon: Icons.build,
                        onChanged: (val) => setState(() => _maintenanceResponsibility = val!),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Maintenance Amount (₹)',
                        initialValue: _flatMaintenanceAmount,
                        hint: 'e.g., 1500',
                        icon: Icons.currency_rupee,
                        keyboardType: TextInputType.number,
                        onSaved: (value) => _flatMaintenanceAmount = value ?? '',
                        validator: (value) => null,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Maintenance Frequency',
                        value: _maintenanceFrequency,
                        items: _maintenanceFrequencies,
                        icon: Icons.update,
                        onChanged: (val) => setState(() => _maintenanceFrequency = val!),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _updateProperty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF808000),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0xFF808000).withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Update Property', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required String hint,
    required IconData icon,
    required void Function(String?) onSaved,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          onSaved: onSaved,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
