import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_snackbar.dart';

class MaintenanceDialog extends StatefulWidget {
  const MaintenanceDialog({super.key});

  @override
  State<MaintenanceDialog> createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends State<MaintenanceDialog> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _properties = [];
  Map<String, dynamic>? _selectedProperty;
  
  String _issueType = 'Apartment / House Maintenance';
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _paidBy = 'Owner';
  String _status = 'Pending';
  DateTime _selectedDate = DateTime.now();

  final List<String> _issueTypes = ['Apartment / House Maintenance', 'Plumbing', 'Electrical', 'Painting', 'Door/Lock', 'Water', 'Other'];
  final List<String> _paidByOptions = ['Owner', 'Tenant'];
  final List<String> _statusOptions = ['Pending', 'In Progress', 'Completed'];

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    try {
      final properties = await _supabaseService.getProperties();
      setState(() {
        _properties = properties;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading properties: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedProperty == null) return;
    
    if (_descriptionController.text.isEmpty || _amountController.text.isEmpty) {
      AppSnackBar.showError(context, 'Please fill description and amount');
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      await _supabaseService.recordMaintenance({
        'property_id': _selectedProperty!['id'],
        'issue_type': _issueType,
        'description': _descriptionController.text,
        'amount': double.parse(_amountController.text),
        'paid_by': _paidBy,
        'status': _status,
        'date': _selectedDate.toIso8601String(),
      });
      
      if (mounted) {
        Navigator.pop(context, true); // Close and indicate success
        AppSnackBar.showSuccess(context, 'Maintenance recorded successfully!');
      }
    } catch (e) {
      debugPrint('Error recording maintenance: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Failed to record maintenance: ${AppSnackBar.cleanErrorMessage(e)}',
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Maintenance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ))
          else ...[
            DropdownButtonFormField<Map<String, dynamic>>(
              decoration: const InputDecoration(
                labelText: 'Select Property',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              items: _properties.map((prop) {
                final buildingName = prop['buildings']?['name'];
                final propNo = prop['property_no'] ?? '';
                final displayName = buildingName != null ? '$buildingName - $propNo' : propNo;
                return DropdownMenuItem(
                  value: prop,
                  child: Text(displayName),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedProperty = val),
            ),
            const SizedBox(height: 16),
            if (_selectedProperty != null) ...[
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    "${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}",
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _issueType,
                decoration: const InputDecoration(
                  labelText: 'Issue Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.build),
                ),
                items: _issueTypes.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _issueType = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _paidBy,
                      decoration: const InputDecoration(
                        labelText: 'Paid By',
                        border: OutlineInputBorder(),
                      ),
                      items: _paidByOptions.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _paidBy = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: _statusOptions.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF808000),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: const Color(0xFF808000).withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Save Maintenance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
          const SizedBox(height: 24),
        ],
      ),
      ),
      ),
    );
  }
}
