import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/app_snackbar.dart';

class AddBuildingDialog extends StatefulWidget {
  final Map<String, dynamic>? building; // Optional building for edit mode

  const AddBuildingDialog({super.key, this.building});

  @override
  State<AddBuildingDialog> createState() => _AddBuildingDialogState();
}

class _AddBuildingDialogState extends State<AddBuildingDialog> {
  final _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.building?['name'] ?? '');
    _addressController = TextEditingController(text: widget.building?['address'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
      };

      if (widget.building != null) {
        await _supabaseService.updateBuilding(widget.building!['id'].toString(), payload);
      } else {
        await _supabaseService.addBuilding(payload);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
        AppSnackBar.showSuccess(context, widget.building != null ? 'Building updated successfully!' : 'Building added successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.showError(context, 'Failed: ${AppSnackBar.cleanErrorMessage(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.business, color: Color(0xFF808000), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.building != null ? 'Edit Master Building' : 'Add Master Building',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Building / Complex Name',
                  prefixIcon: const Icon(Icons.apartment),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Address required' : null,
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF808000),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0xFF808000).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(widget.building != null ? 'Update Building' : 'Add Building'),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
