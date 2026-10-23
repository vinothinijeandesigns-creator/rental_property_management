import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/supabase_service.dart';
import 'property_details_screen.dart';
import 'add_property_screen.dart';
import 'edit_property_screen.dart';
import '../utils/app_snackbar.dart';

class PropertiesScreen extends StatefulWidget {
  final String? buildingId;
  final String? buildingName;

  const PropertiesScreen({super.key, this.buildingId, this.buildingName});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> properties = [];
  bool isLoading = true;
  String _selectedFilter = 'All'; // Filter state

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() => isLoading = true);
    try {
      final data = await _supabaseService.getPropertiesWithDetails(buildingId: widget.buildingId);
      setState(() {
        properties = data;
      });
    } catch (e) {
      debugPrint('Error loading properties: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apply filter
    final filteredProperties = properties.where((p) {
      if (_selectedFilter == 'All') return true;
      return p['status'] == _selectedFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.buildingName ?? 'Properties'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.filter),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Properties')),
              const PopupMenuItem(value: 'Occupied', child: Text('Occupied')),
              const PopupMenuItem(value: 'Vacant', child: Text('Vacant')),
            ],
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddPropertyScreen(buildingId: widget.buildingId)),
              );
              if (result == true) {
                _loadProperties(); // Reload if new property added
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredProperties.isEmpty
              ? const Center(child: Text('No properties found.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProperties.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final prop = filteredProperties[index];
                    final isVacant = prop['status'] == 'Vacant';
                    
                    String tenantName = '-';
                    String rentAmount = '-';
                    int previousTenantsCount = 0;
                    
                    if (prop['agreements'] != null && (prop['agreements'] as List).isNotEmpty) {
                      final agreements = prop['agreements'] as List;
                      previousTenantsCount = agreements.length - (isVacant ? 0 : 1);
                      if (previousTenantsCount < 0) previousTenantsCount = 0;
                      
                      final activeAgreement = agreements[0];
                      if (activeAgreement['monthly_rent'] != null) {
                        rentAmount = '₹${activeAgreement['monthly_rent']}';
                      }
                      if (activeAgreement['tenants'] != null) {
                        tenantName = activeAgreement['tenants']['name'] ?? '-';
                      }
                    }

                    return InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PropertyDetailsScreen(
                              propertyId: prop['id'],
                              propertyName: prop['property_no'] ?? 'Property Details',
                            ),
                          ),
                        );
                        _loadProperties();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isVacant ? Colors.orange.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2),
                            width: isVacant ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        prop['property_type'] == 'House' ? LucideIcons.home : LucideIcons.store,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        prop['property_no'] ?? 'Unknown',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isVacant ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          prop['status'] ?? 'Unknown',
                                          style: TextStyle(
                                            color: isVacant ? Colors.orange : Colors.green,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                        padding: EdgeInsets.zero,
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => EditPropertyScreen(property: prop),
                                              ),
                                            );
                                            if (result == true) {
                                              _loadProperties(); // Reload properties if updated
                                            }
                                          } else if (value == 'delete') {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete Property?'),
                                                content: const Text('Are you sure you want to delete this property? This action cannot be undone.'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              try {
                                                await _supabaseService.deleteProperty(prop['id'].toString());
                                                _loadProperties();
                                                if (context.mounted) AppSnackBar.showSuccess(context, 'Property deleted');
                                              } catch (e) {
                                                if (context.mounted) AppSnackBar.showError(context, 'Failed to delete: ${AppSnackBar.cleanErrorMessage(e)}');
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tenant', style: Theme.of(context).textTheme.bodyMedium),
                                      const SizedBox(height: 4),
                                      Text(
                                        tenantName,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                                      ),
                                      if (previousTenantsCount > 0) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Previous Tenants: $previousTenantsCount',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (!isVacant)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('Due Amount', style: Theme.of(context).textTheme.bodyMedium),
                                        const SizedBox(height: 4),
                                        Text(
                                          prop['total_due'] != null && prop['total_due'] > 0 ? '₹${prop['total_due']}' : 'No Dues',
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: (prop['total_due'] != null && prop['total_due'] > 0) ? Colors.red : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Rent', style: Theme.of(context).textTheme.bodyMedium),
                                      const SizedBox(height: 4),
                                      Text(
                                        rentAmount,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
