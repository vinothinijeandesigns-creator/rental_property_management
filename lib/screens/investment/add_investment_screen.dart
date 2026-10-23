import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_snackbar.dart';

class AddInvestmentScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const AddInvestmentScreen({super.key, this.initialData});

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  
  // Lending specific fields
  final _borrowerPhoneController = TextEditingController();
  final _frequencyController = TextEditingController(text: 'Monthly');
  final _lendingInterestTypeController = TextEditingController(text: 'Simple');
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    final data = widget.initialData!;
    final details = data['details'] ?? {};

    _titleController.text = data['title'] ?? '';
    _amountController.text = data['principal_amount']?.toString() ?? '';
    _rateController.text = data['interest_rate']?.toString() ?? '';
    
    if (data['start_date'] != null) {
      _startDate = DateTime.tryParse(data['start_date']) ?? DateTime.now();
    }
    if (data['end_date'] != null) {
      _endDate = DateTime.tryParse(data['end_date']);
    }

    _borrowerPhoneController.text = details['borrower_phone'] ?? '';
    _frequencyController.text = details['frequency'] ?? 'Monthly';
    _lendingInterestTypeController.text = details['interest_type'] ?? 'Simple';
    _purposeController.text = details['purpose'] ?? '';
    _notesController.text = details['notes'] ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _borrowerPhoneController.dispose();
    _frequencyController.dispose();
    _lendingInterestTypeController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  String get _appBarTitle {
    return widget.initialData != null ? 'Edit Lending' : 'Add Lending';
  }

  Future<void> _saveInvestment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> details = {
        'borrower_phone': _borrowerPhoneController.text,
        'frequency': _frequencyController.text,
        'interest_type': _lendingInterestTypeController.text,
        'purpose': _purposeController.text,
        'notes': _notesController.text,
      };
      
      String finalTitle = _titleController.text;

      final payload = {
        'type': 'Lending',
        'title': finalTitle.isEmpty ? 'Lending' : finalTitle,
        'principal_amount': double.tryParse(_amountController.text) ?? 0,
        'interest_rate': double.tryParse(_rateController.text) ?? 0,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
        'status': 'Active',
        'details': details,
      };

      if (widget.initialData != null) {
        await _supabaseService.updateInvestment(widget.initialData!['id'], payload);
      } else {
        await _supabaseService.addInvestment(payload);
      }
      
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          widget.initialData != null ? 'Lending updated successfully' : 'Lending added successfully',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, AppSnackBar.cleanErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_appBarTitle, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLendingForm(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveInvestment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF808000),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0xFF808000).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save Lending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildCard({required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime current, ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) onChanged(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, icon: const Icon(LucideIcons.calendar)),
        child: Text(DateFormat('dd MMM yyyy').format(current)),
      ),
    );
  }

  Widget _buildLendingForm() {
    return _buildCard(children: [
      TextFormField(
        controller: _titleController,
        decoration: const InputDecoration(labelText: 'Borrower Name', icon: Icon(LucideIcons.user)),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _borrowerPhoneController,
        decoration: const InputDecoration(labelText: 'Phone Number', icon: Icon(LucideIcons.phone)),
        keyboardType: TextInputType.phone,
        validator: (v) {
          if (v != null && v.isNotEmpty && v.length < 10) return 'Enter a valid phone number';
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _amountController,
        decoration: const InputDecoration(labelText: 'Principal Amount (₹)', icon: Icon(LucideIcons.banknote)),
        keyboardType: TextInputType.number,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          final amount = double.tryParse(v);
          if (amount == null) return 'Please enter a valid number';
          if (amount <= 0) return 'Amount must be greater than 0';
          return null;
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _rateController,
              decoration: const InputDecoration(labelText: 'Interest Rate (%)', icon: Icon(LucideIcons.percent)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Builder(
              builder: (context) {
                const frequencyOptions = ['Monthly', 'Quarterly', 'Yearly'];
                final selectedFrequency = frequencyOptions.contains(_frequencyController.text)
                    ? _frequencyController.text
                    : 'Monthly';
                return DropdownButtonFormField<String>(
                  initialValue: selectedFrequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: frequencyOptions.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() => _frequencyController.text = newValue);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Builder(
        builder: (context) {
          const interestOptions = ['Simple', 'Compound', 'Non-Cumulative', 'Cumulative'];
          final selectedInterestType = interestOptions.contains(_lendingInterestTypeController.text)
              ? _lendingInterestTypeController.text
              : 'Simple';
          return DropdownButtonFormField<String>(
            initialValue: selectedInterestType,
            decoration: const InputDecoration(labelText: 'Interest Type', icon: Icon(LucideIcons.settings)),
            items: interestOptions.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() => _lendingInterestTypeController.text = newValue);
              }
            },
          );
        },
      ),
      const SizedBox(height: 12),
      _buildDatePicker('Start Date', _startDate, (d) => setState(() => _startDate = d)),
      const SizedBox(height: 12),
      _buildDatePicker('End Date (Optional)', _endDate ?? DateTime.now(), (d) => setState(() => _endDate = d)),
      const SizedBox(height: 12),
      TextFormField(
        controller: _purposeController,
        decoration: const InputDecoration(labelText: 'Purpose', icon: Icon(LucideIcons.target)),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _notesController,
        decoration: const InputDecoration(labelText: 'Notes', icon: Icon(LucideIcons.fileText)),
        maxLines: 2,
      ),
    ]);
  }
}
