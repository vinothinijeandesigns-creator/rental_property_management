import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../utils/app_snackbar.dart';
import 'add_building_dialog.dart';

class AddPropertyScreen extends StatefulWidget {
  final String? buildingId;
  const AddPropertyScreen({super.key, this.buildingId});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  String _propertyNo = '';
  String _propertyType = 'House';
  String _status = 'Vacant';

  String _advanceAmount = '';
  String _advanceDate = '';
  String _monthlyRent = '';
  String _rentDueDate = '';
  String _rentStartDate = '';
  String _rentEndDate = '';

  String _ebMeterNumber = '';
  String _waterCharge = '';
  String _maintenanceResponsibility = 'Owner';
  String _tenantName = '';
  String _tenantPhone = '';
  String _idDocument = '';

  final List<String> _propertyTypes = ['House', 'Shop', 'Flat', 'Warehouse'];
  final List<String> _statuses = ['Vacant', 'Occupied'];
  final List<String> _maintenanceResponsibilities = ['Owner', 'Tenant'];
  
  String _flatMaintenanceAmount = '';
  String _maintenanceFrequency = '1 Month';
  final List<String> _maintenanceFrequencies = ['1 Month', '3 Months', '6 Months', '12 Months'];

  final _advanceDateController = TextEditingController();
  final _rentStartDateController = TextEditingController();
  final _rentEndDateController = TextEditingController();

  List<Map<String, dynamic>> _buildings = [];
  String? _selectedBuildingId;
  bool _isLoadingBuildings = true;

  @override
  void initState() {
    super.initState();
    _selectedBuildingId = widget.buildingId;
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    try {
      final buildings = await _supabaseService.getBuildings();
      if (context.mounted) {
        setState(() {
          _buildings = buildings;
          _isLoadingBuildings = false;
        });

        if (buildings.isEmpty) {
          _showNoBuildingsDialog();
        } else if (_selectedBuildingId == null && buildings.isNotEmpty) {
          _selectedBuildingId = buildings.first['id'].toString();
        }
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isLoadingBuildings = false);
      }
    }
  }

  void _showNoBuildingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Master Building Required'),
        content: const Text('You must create a Master Building (e.g., an Apartment Complex or a Standalone Property Group) before adding individual flats/houses.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close add property screen
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              final result = await showDialog(
                context: context,
                builder: (context) => const AddBuildingDialog(),
              );
              if (result == true) {
                _loadBuildings(); // Reload to get the new building
              } else {
                if (context.mounted) Navigator.pop(context); // Close add property screen if they didn't add
              }
            },
            child: const Text('Create Now'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _advanceDateController.dispose();
    _rentStartDateController.dispose();
    _rentEndDateController.dispose();
    super.dispose();
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) return;
    
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final propertyData = {
        'property_no': _propertyNo,
        'property_type': _propertyType,
        'status': _status,
        'eb_meter_number': _ebMeterNumber,
        'water_charge': _waterCharge,
        'maintenance_responsibility': _maintenanceResponsibility,
        'flat_maintenance_amount': _flatMaintenanceAmount,
        'maintenance_frequency': _maintenanceFrequency,
        if (_selectedBuildingId != null) 'building_id': _selectedBuildingId,
      };

      if (_status == 'Occupied') {
        propertyData['advance_amount'] = _advanceAmount;
        propertyData['advance_date'] = _advanceDate;
        propertyData['monthly_rent'] = _monthlyRent;
        propertyData['rent_due_date'] = _rentDueDate;
        propertyData['rent_start_date'] = _rentStartDate;
        propertyData['rent_end_date'] = _rentEndDate;
        propertyData['tenant_name'] = _tenantName;
        propertyData['tenant_phone'] = _tenantPhone;
        propertyData['id_document'] = _idDocument;
      }

      await _supabaseService.addProperty(propertyData);

      if (mounted) {
        AppSnackBar.showSuccess(context, 'Property added successfully!');
        Navigator.pop(context, true); // Return true to indicate success and trigger reload
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to add property: ${AppSnackBar.cleanErrorMessage(e)}');
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
        title: const Text('Add New Property', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
                      if (widget.buildingId == null && !_isLoadingBuildings && _buildings.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedBuildingId,
                          decoration: InputDecoration(
                            labelText: 'Master Building',
                            prefixIcon: const Icon(Icons.business),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _buildings.map((b) {
                            return DropdownMenuItem<String>(
                              value: b['id'].toString(),
                              child: Text(b['name']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedBuildingId = val;
                            });
                          },
                          validator: (val) => val == null ? 'Please select a building' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildTextField(
                        label: 'Property No / Name',
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
                        hint: 'e.g., 123-456-789',
                        icon: Icons.electric_meter,
                        onSaved: (value) => _ebMeterNumber = value ?? '',
                        validator: (value) => null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Water Charge (₹)',
                        hint: 'e.g., 500',
                        icon: Icons.water_drop,
                        keyboardType: TextInputType.number,
                        onSaved: (value) => _waterCharge = value ?? '',
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
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
                        hint: 'e.g., 1500',
                        icon: Icons.currency_rupee,
                        keyboardType: TextInputType.number,
                        onSaved: (value) => _flatMaintenanceAmount = value ?? '',
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Maintenance Frequency',
                        value: _maintenanceFrequency,
                        items: _maintenanceFrequencies,
                        icon: Icons.update,
                        onChanged: (val) => setState(() => _maintenanceFrequency = val!),
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Status',
                        value: _status,
                        items: _statuses,
                        icon: Icons.info_outline,
                        onChanged: (val) => setState(() => _status = val!),
                      ),
                      if (_status == 'Occupied') ...[
                        const SizedBox(height: 24),
                        const Text('Tenant Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Tenant Name',
                          hint: 'e.g., Suresh',
                          icon: Icons.person,
                          onSaved: (value) => _tenantName = value ?? '',
                          validator: (value) => _status == 'Occupied' && (value == null || value.isEmpty) ? 'Required field' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Mobile Number',
                          hint: 'e.g., 9876543210',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSaved: (value) => _tenantPhone = value ?? '',
                          validator: (value) => _status == 'Occupied' && (value == null || value.isEmpty) ? 'Required field' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'ID Document Details',
                          hint: 'e.g., Aadhar: 1234 5678 9012',
                          icon: Icons.badge,
                          onSaved: (value) => _idDocument = value ?? '',
                          validator: (value) => null,
                        ),
                        const SizedBox(height: 24),
                        const Text('Rental Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Advance Amount',
                          hint: 'e.g., 50000',
                          icon: Icons.currency_rupee,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSaved: (value) => _advanceAmount = value ?? '',
                          validator: (value) {
                            if (_status == 'Occupied' && (value == null || value.isEmpty)) return 'Required field';
                            if (value != null && value.isNotEmpty && double.tryParse(value) == null) return 'Please enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDateField(
                          context: context,
                          label: 'Advance Date',
                          hint: 'e.g., 2026-08-01',
                          controller: _advanceDateController,
                          onSaved: (value) => _advanceDate = value ?? '',
                          validator: (value) => _status == 'Occupied' && (value == null || value.isEmpty) ? 'Required field' : null,
                          onDateSelected: (date) {
                            final expiryDate = DateTime(date.year, date.month + 11, date.day);
                            final formatted = "${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}";
                            _rentEndDateController.text = formatted;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Monthly Rent',
                          hint: 'e.g., 8500',
                          icon: Icons.currency_rupee,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSaved: (value) => _monthlyRent = value ?? '',
                          validator: (value) {
                            if (_status == 'Occupied' && (value == null || value.isEmpty)) return 'Required field';
                            if (value != null && value.isNotEmpty && double.tryParse(value) == null) return 'Please enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: 'Rent Due Date',
                          value: _rentDueDate.isEmpty ? '5' : _rentDueDate,
                          items: List.generate(31, (index) => (index + 1).toString()),
                          icon: Icons.event,
                          onChanged: (val) => setState(() => _rentDueDate = val!),
                        ),
                        const SizedBox(height: 16),
                        _buildDateField(
                          context: context,
                          label: 'Month Rent Start Date',
                          hint: 'e.g., 2026-08-01',
                          controller: _rentStartDateController,
                          onSaved: (value) => _rentStartDate = value ?? '',
                          validator: (value) => _status == 'Occupied' && (value == null || value.isEmpty) ? 'Required field' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildDateField(
                          context: context,
                          label: 'Agreement Expiry Date',
                          hint: 'e.g., 2027-07-31',
                          controller: _rentEndDateController,
                          onSaved: (value) => _rentEndDate = value ?? '',
                          validator: (value) => _status == 'Occupied' && (value == null || value.isEmpty) ? 'Required field' : null,
                        ),
                      ],
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _saveProperty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF808000),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0xFF808000).withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save Property', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    required String hint,
    required IconData icon,
    required void Function(String?) onSaved,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        TextFormField(
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
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

  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required String hint,
    required TextEditingController controller,
    required void Function(String?) onSaved,
    required String? Function(String?) validator,
    void Function(DateTime)? onDateSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              final formatted = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
              controller.text = formatted;
              if (onDateSelected != null) {
                onDateSelected(date);
              }
            }
          },
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(Icons.calendar_today, color: Colors.grey.shade400),
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
