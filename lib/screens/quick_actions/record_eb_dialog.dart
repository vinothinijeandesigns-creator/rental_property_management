import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_snackbar.dart';

class RecordEBDialog extends StatefulWidget {
  final DateTime selectedMonth;
  const RecordEBDialog({super.key, required this.selectedMonth});

  @override
  State<RecordEBDialog> createState() => _RecordEBDialogState();
}

class _RecordEBDialogState extends State<RecordEBDialog> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _properties = [];
  Map<String, dynamic>? _selectedProperty;
  
  double _previousReading = 0.0;
  
  final _currentReadingController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueDateController = TextEditingController();

  double _units = 0.0;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.selectedMonth;
    _loadProperties();
    _currentReadingController.addListener(_calculateUnits);
  }



  @override
  void dispose() {
    _currentReadingController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
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

  Future<void> _onPropertySelected(Map<String, dynamic>? property) async {
    setState(() {
      _selectedProperty = property;
      _previousReading = 0.0;
      _currentReadingController.clear();
      _amountController.clear();
      _dueDateController.clear();
    });

    if (property != null) {
      final prev = await _supabaseService.getPreviousEBReading(property['id'].toString());
      if (mounted) {
        setState(() {
          _previousReading = prev ?? 0.0;
        });
      }
    }
  }

  void _calculateUnits() {
    final currentStr = _currentReadingController.text;
    if (currentStr.isEmpty) {
      setState(() => _units = 0.0);
      return;
    }
    
    final current = double.tryParse(currentStr) ?? 0.0;
    setState(() {
      _units = current - _previousReading;
      if (_units < 0) _units = 0;
    });
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) {
      setState(() {
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedProperty == null) return;
    
    if (_currentReadingController.text.isEmpty || _amountController.text.isEmpty || _dueDateController.text.isEmpty) {
      AppSnackBar.showError(context, 'Please fill all fields');
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      final currentMonth = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

      await _supabaseService.recordEB({
        'property_id': _selectedProperty!['id'],
        'billing_month': currentMonth,
        'previous_reading': _previousReading,
        'current_reading': double.parse(_currentReadingController.text),
        'units': _units,
        'bill_amount': double.parse(_amountController.text),
        'due_date': _dueDateController.text,
      });
      
      if (mounted) {
        Navigator.pop(context, true); // Close and indicate success
        AppSnackBar.showSuccess(context, 'EB Bill recorded successfully!');
      }
    } catch (e) {
      debugPrint('Error recording EB: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to record EB: ${AppSnackBar.cleanErrorMessage(e)}');
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Record EB Bill', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
              onChanged: _onPropertySelected,
            ),
            const SizedBox(height: 16),
            if (_selectedProperty != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Previous Reading: $_previousReading', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentReadingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Current Reading',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
              ),
              const SizedBox(height: 8),
              Text('Units Consumed: ${_units.toStringAsFixed(1)}', 
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'EB Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dueDateController,
                readOnly: true,
                onTap: () => _selectDueDate(context),
                decoration: const InputDecoration(
                  labelText: 'Due Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
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
                    : const Text('Save Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
