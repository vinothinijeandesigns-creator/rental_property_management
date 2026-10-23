import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'supabase_service.dart';

class ExportService {
  final SupabaseService _supabaseService = SupabaseService();

  Future<void> exportFinanceDataToCSV() async {
    try {
      // 1. Fetch all data
      final rents = await _supabaseService.getAllRents();
      final ebBills = await _supabaseService.getAllEBBills();
      final maintenance = await _supabaseService.getAllMaintenanceRecords();

      if (rents.isEmpty && ebBills.isEmpty && maintenance.isEmpty) {
        throw Exception('No finance data available to export.');
      }

      // 2. Prepare headers
      List<List<dynamic>> csvData = [
        ['Date/Month', 'Type', 'Property', 'Details', 'Amount (₹)', 'Status'],
      ];

      // 3. Process Rents
      for (var rent in rents) {
        final propNo = rent['agreements']?['properties']?['property_no'] ?? 'Unknown';
        final tenant = rent['agreements']?['tenants']?['name'] ?? 'Unknown';
        final amount = rent['rent_amount'] ?? rent['agreements']?['monthly_rent'] ?? 0;
        final month = rent['payment_month'] ?? '';
        final status = rent['status'] ?? 'Unknown';
        
        csvData.add([
          month,
          'Rent',
          propNo,
          'Tenant: $tenant',
          amount,
          status,
        ]);
      }

      // 4. Process EB Bills
      for (var eb in ebBills) {
        final propNo = eb['properties']?['property_no'] ?? 'Unknown';
        final amount = eb['bill_amount'] ?? 0;
        final month = eb['billing_month'] ?? '';
        final units = eb['units'] ?? 0;
        final status = eb['status'] ?? 'Unknown';
        
        csvData.add([
          month,
          'EB Bill',
          propNo,
          '$units Units',
          amount,
          status,
        ]);
      }

      // 5. Process Maintenance
      for (var req in maintenance) {
        final propNo = req['properties']?['property_no'] ?? 'Unknown';
        final amount = req['amount'] ?? 0;
        final date = req['date'] != null ? req['date'].toString().split('T')[0] : '';
        final details = req['issue_description'] ?? req['issue_type'] ?? 'Maintenance';
        final status = req['status'] ?? 'Unknown';
        
        csvData.add([
          date,
          'Maintenance',
          propNo,
          details,
          amount,
          status,
        ]);
      }

      // Sort rows by Date descending (skipping header)
      final header = csvData.removeAt(0);
      csvData.sort((a, b) => b[0].toString().compareTo(a[0].toString()));
      csvData.insert(0, header);

      // 6. Generate CSV String
      String csvContent = Csv().encode(csvData);

      // 7. Save to temp file
      final directory = await getTemporaryDirectory();
      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final String filePath = '${directory.path}/Finance_Report_$timestamp.csv';
      
      final File file = File(filePath);
      await file.writeAsString(csvContent);

      // 8. Share the file
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Rental Finance Report - $timestamp',
      );

    } catch (e) {
      throw Exception('Failed to export data: $e');
    }
  }
}
