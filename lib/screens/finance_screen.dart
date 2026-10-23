import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

import '../services/export_service.dart';
import '../utils/app_snackbar.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final ExportService _exportService = ExportService();
  bool _isExporting = false;

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      await _exportService.exportFinanceDataToCSV();
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        if (errorMsg.contains('No finance data')) {
          AppSnackBar.showError(context, 'No finance data available to export.');
        } else {
          AppSnackBar.showError(context, 'Export failed: ${AppSnackBar.cleanErrorMessage(e)}');
        }
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finance'),
          actions: [
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.file_download, color: Color(0xFF808000)),
                tooltip: 'Export Data',
                onPressed: _handleExport,
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Rent'),
              Tab(text: 'EB Bill'),
              Tab(text: 'Maintenance'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RentTab(),
            _EBTab(),
            _MaintenanceTab(),
          ],
        ),
      ),
    );
  }
}

class _RentTab extends StatefulWidget {
  const _RentTab();

  @override
  State<_RentTab> createState() => _RentTabState();
}

class _RentTabState extends State<_RentTab> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _rents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _rents = await _supabaseService.getAllRents();
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildRentCard(Map<String, dynamic> rent) {
    final isPaid = rent['status'] == 'Paid';
    final propNo = rent['agreements']?['properties']?['property_no'] ?? 'Unknown Property';
    final tenantName = rent['agreements']?['tenants']?['name'] ?? 'Unknown Tenant';
    final amount = rent['rent_amount'] ?? rent['agreements']?['monthly_rent'] ?? 0;
    final month = rent['payment_month'] ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPaid ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
          child: Icon(
            isPaid ? LucideIcons.check : LucideIcons.clock,
            color: isPaid ? Colors.green : Colors.red,
          ),
        ),
        title: Text('$propNo ($month)', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(tenantName),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              rent['status'] ?? '',
              style: TextStyle(
                color: isPaid ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_rents.isEmpty) return const Center(child: Text('No rent records found'));

    final now = DateTime.now();
    final currentMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final currentMonthRecords = _rents.where((r) => r['payment_month'] == currentMonthStr).toList();
    final previousRecords = _rents.where((r) => r['payment_month'] != currentMonthStr).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (currentMonthRecords.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Current Month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          ...currentMonthRecords.map((r) => _buildRentCard(r)),
        ],
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Previous Finance Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF808000))),
            children: previousRecords.isEmpty 
              ? [const Padding(padding: EdgeInsets.all(16.0), child: Text('No previous records found'))]
              : previousRecords.map((r) => _buildRentCard(r)).toList(),
          ),
        ),
      ],
    );
  }
}

class _EBTab extends StatefulWidget {
  const _EBTab();

  @override
  State<_EBTab> createState() => _EBTabState();
}

class _EBTabState extends State<_EBTab> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _ebBills = [];
  List<Map<String, dynamic>> _properties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _ebBills = await _supabaseService.getAllEBBills();
    final allProps = await _supabaseService.getPropertiesWithDetails();
    _properties = allProps.where((p) => p['status'] == 'Occupied').toList();
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildEBCard(Map<String, dynamic> bill) {
    final isDummy = bill['is_dummy'] == true;
    final propNo = bill['properties']?['property_no'] ?? 'Unknown Property';
    final amount = bill['bill_amount'] ?? 0;
    final units = bill['units'] ?? 0;
    final month = bill['billing_month'] ?? '';
    final status = bill['status'] ?? 'Pending';
    final isPaid = status == 'Paid';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isDummy ? null : () {
          if (!isPaid) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Mark as Paid?'),
                content: const Text('Do you want to mark this EB bill as paid?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      try {
                        await _supabaseService.markEBBillAsPaid(bill['id']);
                        await _loadData();
                        if (context.mounted) {
                          AppSnackBar.showSuccess(context, 'EB Bill marked as paid!');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => _isLoading = false);
                          AppSnackBar.showError(context, 'Failed: ${AppSnackBar.cleanErrorMessage(e)}');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Yes, Paid', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          } else {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Undo Payment?'),
                content: const Text('Do you want to mark this EB bill as Pending?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      try {
                        await _supabaseService.undoMarkEBBillAsPaid(bill['id']);
                        await _loadData();
                        if (context.mounted) {
                          AppSnackBar.showSuccess(context, 'EB Bill marked as pending!');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => _isLoading = false);
                          AppSnackBar.showError(context, 'Failed: ${AppSnackBar.cleanErrorMessage(e)}');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Yes, Undo', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.withValues(alpha: 0.1),
            child: const Icon(LucideIcons.zap, color: Colors.blue),
          ),
          title: Text('$propNo ($month)', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('$units Units'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                status,
                style: TextStyle(
                  color: isPaid ? Colors.green : (isDummy ? Colors.grey : Colors.red),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final now = DateTime.now();
    final currentMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final currentMonthRecords = <Map<String, dynamic>>[];
    for (var prop in _properties) {
      final billsForProp = _ebBills.where((b) => b['billing_month'] == currentMonthStr && b['properties']?['id'] == prop['id']);
      if (billsForProp.isNotEmpty) {
        currentMonthRecords.add(billsForProp.first);
      } else {
        currentMonthRecords.add({
          'is_dummy': true,
          'properties': prop,
          'billing_month': currentMonthStr,
          'bill_amount': 0,
          'units': 0,
          'status': 'Not Recorded',
        });
      }
    }

    final previousRecords = _ebBills.where((b) => b['billing_month'] != currentMonthStr).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (currentMonthRecords.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Current Month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          ...currentMonthRecords.map((b) => _buildEBCard(b)),
        ],
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Previous Finance Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF808000))),
            children: previousRecords.isEmpty 
              ? [const Padding(padding: EdgeInsets.all(16.0), child: Text('No previous records found'))]
              : previousRecords.map((b) => _buildEBCard(b)).toList(),
          ),
        ),
      ],
    );
  }
}

class _MaintenanceTab extends StatefulWidget {
  const _MaintenanceTab();

  @override
  State<_MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<_MaintenanceTab> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _properties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _records = await _supabaseService.getAllMaintenanceRecords();
    final allProps = await _supabaseService.getPropertiesWithDetails();
    _properties = allProps.where((p) => p['status'] == 'Occupied').toList();
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildMaintenanceCard(Map<String, dynamic> record) {
    final isDummy = record['is_dummy'] == true;
    final propNo = record['properties']?['property_no'] ?? 'Unknown Property';
    final amount = record['amount'] ?? 0;
    final issueType = record['issue_type'] ?? '';
    final desc = record['description'] ?? '';
    final paidBy = record['paid_by'] ?? '';
    
    DateTime? date;
    if (record['date'] != null) {
      date = DateTime.tryParse(record['date']);
    }
    final dateStr = date != null ? DateFormat('MMM d, yyyy').format(date) : '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isDummy ? () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Record Maintenance?'),
              content: const Text('Do you want to record this regular maintenance as Paid?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    try {
                      await _supabaseService.recordMaintenance({
                        'property_id': record['properties']['id'],
                        'issue_type': 'Regular Maintenance',
                        'description': 'Regular maintenance payment',
                        'amount': record['amount'],
                        'paid_by': record['paid_by'],
                        'status': 'Paid',
                        'date': DateTime.now().toIso8601String(),
                      });
                      await _loadData();
                      if (context.mounted) {
                        AppSnackBar.showSuccess(context, 'Maintenance recorded successfully!');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => _isLoading = false);
                        AppSnackBar.showError(context, 'Failed: ${AppSnackBar.cleanErrorMessage(e)}');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Yes, Record', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        } : () {
          final currentStatus = record['status'] ?? 'Pending';
          if (currentStatus != 'Paid') {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Mark as Paid?'),
                content: const Text('Has this maintenance amount been settled?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      try {
                        await _supabaseService.markMaintenanceAsPaid(record['id']);
                        await _loadData();
                        if (context.mounted) {
                          AppSnackBar.showSuccess(context, 'Maintenance marked as paid!');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => _isLoading = false);
                          AppSnackBar.showError(context, 'Failed: ${AppSnackBar.cleanErrorMessage(e)}');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Yes, Settled', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          } else {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Undo Settlement?'),
                content: const Text('Has this maintenance amount not been settled? Mark as Pending?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      try {
                        await _supabaseService.undoMarkMaintenanceAsPaid(record['id']);
                        await _loadData();
                        if (context.mounted) {
                          AppSnackBar.showSuccess(context, 'Maintenance marked as pending!');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => _isLoading = false);
                          AppSnackBar.showError(context, 'Failed: ${AppSnackBar.cleanErrorMessage(e)}');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Yes, Undo', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.purple.withValues(alpha: 0.1),
            child: const Icon(LucideIcons.wrench, color: Colors.purple),
          ),
          title: Text('$propNo - $issueType', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (desc.isNotEmpty) Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('Paid by: $paidBy', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                record['status'] == 'Paid' ? 'Paid' : (record['status'] ?? 'Pending'),
                style: TextStyle(
                  color: record['status'] == 'Paid' ? Colors.green : (isDummy ? Colors.grey : Colors.red),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final now = DateTime.now();

    final currentMonthRecords = <Map<String, dynamic>>[];
    
    // Calculate regular maintenance expected this month
    for (var prop in _properties) {
      final amount = prop['flat_maintenance_amount'];
      final freq = prop['maintenance_frequency'];
      if (amount == null || freq == null || freq == 'N/A') continue;

      int freqMonths = 1;
      if (freq.contains('3')) {
        freqMonths = 3;
      } else if (freq.contains('6')) {
        freqMonths = 6;
      } else if (freq.contains('12')) {
        freqMonths = 12;
      }

      DateTime? startDate;
      if (prop['agreements'] != null && (prop['agreements'] as List).isNotEmpty) {
        final ag = prop['agreements'][0];
        if (ag['start_date'] != null) {
           startDate = DateTime.tryParse(ag['start_date'].toString());
        }
      }
      
      if (startDate != null) {
         int monthsDiff = (now.year - startDate.year) * 12 + now.month - startDate.month;
         if (monthsDiff >= 0 && monthsDiff % freqMonths == 0) {
            final existingRecords = _records.where((r) {
               if (r['properties']?['id'] != prop['id']) return false;
               if (r['issue_type'] != 'Regular Maintenance') return false;
               if (r['date'] == null) return false;
               final d = DateTime.tryParse(r['date']);
               return d != null && d.year == now.year && d.month == now.month;
            });
            if (existingRecords.isNotEmpty) {
               currentMonthRecords.add(existingRecords.first);
            } else {
               currentMonthRecords.add({
                 'is_dummy': true,
                 'properties': prop,
                 'issue_type': 'Regular Maintenance',
                 'description': 'Due for this month',
                 'amount': amount,
                 'paid_by': prop['maintenance_responsibility'] ?? 'Unknown',
                 'status': 'Not Recorded',
                 'date': now.toIso8601String(),
               });
            }
         }
      }
    }
    
    final issueRecordsThisMonth = _records.where((r) {
      if (r['issue_type'] == 'Regular Maintenance') return false;
      if (r['date'] == null) return false;
      final d = DateTime.tryParse(r['date']);
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
    
    currentMonthRecords.addAll(issueRecordsThisMonth);

    final previousRecords = _records.where((r) {
      if (r['date'] == null) return true;
      final d = DateTime.tryParse(r['date']);
      return d == null || d.year != now.year || d.month != now.month;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (currentMonthRecords.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Current Month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          ...currentMonthRecords.map((r) => _buildMaintenanceCard(r)),
        ],
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Previous Finance Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF808000))),
            children: previousRecords.isEmpty 
              ? [const Padding(padding: EdgeInsets.all(16.0), child: Text('No previous records found'))]
              : previousRecords.map((r) => _buildMaintenanceCard(r)).toList(),
          ),
        ),
      ],
    );
  }
}