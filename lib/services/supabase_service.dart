import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // -- Authentication --
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name}, // Store the admin's name in user metadata
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> resetPassword({required String email}) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  Future<void> updateUserProfile({String? name, String? avatarUrl}) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['full_name'] = name;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;

    await _supabase.auth.updateUser(UserAttributes(data: data));
  }

  Future<String> uploadProfilePicture(File file) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Must be logged in to upload a profile picture.');
    }

    final fileExtension = file.path.split('.').last;
    final fileName =
        '${user.id}-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final path = 'avatars/$fileName';

    await _supabase.storage
        .from('avatars')
        .upload(
          path,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    final imageUrl = _supabase.storage.from('avatars').getPublicUrl(path);
    await updateUserProfile(avatarUrl: imageUrl);
    return imageUrl;
  }

  // -- Buildings --
  Future<List<Map<String, dynamic>>> getBuildings() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('buildings')
        .select('*, properties(id)')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final buildings = List<Map<String, dynamic>>.from(response);
    for (var b in buildings) {
      int actualCount = 0;
      if (b['properties'] != null) {
        actualCount = (b['properties'] as List).length;
      }
      b['total_units'] = actualCount;
    }
    return buildings;
  }

  Future<void> addBuilding(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user != null) {
      data['user_id'] = user.id;
    }
    await _supabase.from('buildings').insert(data);
  }

  Future<void> updateBuilding(String id, Map<String, dynamic> data) async {
    await _supabase.from('buildings').update(data).eq('id', id);
  }

  Future<void> deleteBuilding(String id) async {
    await _supabase.from('buildings').delete().eq('id', id);
  }

  // -- Properties --
  Future<List<Map<String, dynamic>>> getProperties({String? buildingId}) async {
    final user = currentUser;
    if (user == null) return [];

    var query = _supabase
        .from('properties')
        .select('*, buildings!inner(user_id, name)')
        .eq('buildings.user_id', user.id);

    if (buildingId != null) {
      query = query.eq('building_id', buildingId);
    }
    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getPropertiesWithDetails({
    String? buildingId,
  }) async {
    final user = currentUser;
    if (user == null) return [];

    // Temporarily auto-fix missing rents for existing properties on load
    try {
      await fixMissingRentsForUser();
    } catch (e) {
      debugPrint('Error fixing missing rents: $e');
    }

    var query = _supabase
        .from('properties')
        .select(
          '*, agreements(id, created_at, start_date, end_date, monthly_rent, tenants(name)), buildings!inner(user_id, name)',
        )
        .eq('buildings.user_id', user.id);

    if (buildingId != null) {
      query = query.eq('building_id', buildingId);
    }
    final response = await query.order('created_at', ascending: false);

    final properties = List<Map<String, dynamic>>.from(response);

    try {
      final pendingRents = await _supabase
          .from('rent_payments')
          .select('pending_amount, agreement_id, agreements!inner(property_id)')
          .eq('status', 'Pending');

      final pendingEBs = await _supabase
          .from('eb_bills')
          .select('bill_amount, property_id')
          .eq('status', 'Pending');

      for (var prop in properties) {
        double totalDue = 0;
        final propId = prop['id'].toString();

        String? activeAgreementId;
        if (prop['agreements'] != null && prop['agreements'] is List) {
          List agreements = List.from(prop['agreements']);
          agreements.sort((a, b) {
            DateTime dateA =
                DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                DateTime(2000);
            DateTime dateB =
                DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                DateTime(2000);
            if (a['created_at'] == null && a['id'] is int && b['id'] is int) {
              return (b['id'] as int).compareTo(a['id'] as int);
            }
            return dateB.compareTo(dateA);
          });
          prop['agreements'] = agreements;
          if (agreements.isNotEmpty && prop['status'] == 'Occupied') {
            activeAgreementId = agreements[0]['id'].toString();
          }
        }

        for (var rent in pendingRents) {
          if (rent['agreements']?['property_id']?.toString() == propId) {
            if (activeAgreementId != null &&
                rent['agreement_id']?.toString() == activeAgreementId) {
              totalDue +=
                  double.tryParse(rent['pending_amount']?.toString() ?? '0') ??
                  0;
            }
          }
        }

        for (var eb in pendingEBs) {
          if (eb['property_id']?.toString() == propId) {
            totalDue +=
                double.tryParse(eb['bill_amount']?.toString() ?? '0') ?? 0;
          }
        }

        prop['total_due'] = totalDue;
      }
    } catch (e) {
      debugPrint('Error fetching dues: $e');
    }

    return properties;
  }

  Future<Map<String, dynamic>> getPropertyDetails(String propertyId) async {
    final response = await _supabase
        .from('properties')
        .select('*, agreements(*, tenants(*)), buildings(address)')
        .eq('id', propertyId)
        .single();
    return response;
  }

  Future<void> updateProperty(String id, Map<String, dynamic> data) async {
    await _supabase.from('properties').update(data).eq('id', id);
  }

  Future<void> deleteProperty(String id) async {
    await _supabase.from('properties').delete().eq('id', id);
  }

  Future<void> addProperty(Map<String, dynamic> data) async {
    // 1. Insert into properties table
    final propertyPayload = {
      'property_no': data['property_no'],
      'property_type': data['property_type'],
      'location': data['location'] ?? '',
      'status': data['status'],
      if (data.containsKey('eb_meter_number'))
        'eb_meter_number': data['eb_meter_number'],
      if (data.containsKey('water_charge'))
        'water_charge': data['water_charge'],
      if (data.containsKey('maintenance_responsibility'))
        'maintenance_responsibility': data['maintenance_responsibility'],
      if (data.containsKey('flat_maintenance_amount'))
        'flat_maintenance_amount': double.tryParse(
          data['flat_maintenance_amount']?.toString() ?? '',
        ),
      if (data.containsKey('maintenance_frequency'))
        'maintenance_frequency': data['maintenance_frequency'],
      if (data.containsKey('building_id')) 'building_id': data['building_id'],
    };

    final propsRes = await _supabase
        .from('properties')
        .insert(propertyPayload)
        .select();

    if (data['status'] == 'Occupied' && propsRes.isNotEmpty) {
      final propertyId = propsRes[0]['id'];

      // 2. Insert into tenants table
      final tenantName = data['tenant_name'] ?? 'Unknown Tenant';
      final tenantPhone = data['tenant_phone'] ?? '';
      final idDocument = data['id_document'] ?? '';

      try {
        final tenantRes = await _supabase.from('tenants').insert({
          'name': tenantName,
          'phone': tenantPhone,
          if (idDocument.isNotEmpty) 'id_document': idDocument,
        }).select();

        if (tenantRes.isNotEmpty) {
          final tenantId = tenantRes[0]['id'];

          double? advanceAmount = double.tryParse(
            data['advance_amount']?.toString() ?? '',
          );
          double? monthlyRent = double.tryParse(
            data['monthly_rent']?.toString() ?? '',
          );

          Map<String, dynamic> agreementPayload = {
            'property_id': propertyId,
            'tenant_id': tenantId,
            'advance_amount': advanceAmount,
            'monthly_rent': monthlyRent,
            'start_date': data['rent_start_date']?.toString().isNotEmpty == true
                ? data['rent_start_date']
                : null,
            'end_date': data['rent_end_date']?.toString().isNotEmpty == true
                ? data['rent_end_date']
                : null,
          };

          final agreementRes = await _supabase
              .from('agreements')
              .insert(agreementPayload)
              .select();

          if (agreementRes.isNotEmpty &&
              data['rent_start_date']?.toString().isNotEmpty == true) {
            await _generateBackdatedRents(
              agreementRes[0]['id'].toString(),
              data['rent_start_date'].toString(),
              monthlyRent ?? 0,
            );
          }
        }
      } on PostgrestException catch (e) {
        if (e.code == '42501') {
          throw Exception(
            'Supabase RLS Error: You must enable INSERT policies for "tenants" and "agreements" tables in your Supabase Dashboard.',
          );
        }
        rethrow;
      }
    }
  }

  Future<void> updateTenantDetails({
    required String tenantId,
    required String name,
    required String phone,
  }) async {
    try {
      await _supabase
          .from('tenants')
          .update({'name': name, 'phone': phone})
          .eq('id', tenantId);
    } catch (e) {
      debugPrint('Error updating tenant: $e');
      rethrow;
    }
  }

  Future<void> assignTenantToProperty({
    required String propertyId,
    required String tenantName,
    required String tenantPhone,
    required double monthlyRent,
    required double advanceAmount,
    required String startDate,
    required String endDate,
  }) async {
    try {
      // 1. Insert Tenant
      final tenantRes = await _supabase.from('tenants').insert({
        'name': tenantName,
        'phone': tenantPhone,
      }).select();

      if (tenantRes.isNotEmpty) {
        final tenantId = tenantRes[0]['id'];

        final agreementRes = await _supabase.from('agreements').insert({
          'property_id': propertyId,
          'tenant_id': tenantId,
          'advance_amount': advanceAmount,
          'monthly_rent': monthlyRent,
          'start_date': startDate,
          'end_date': endDate,
        }).select();

        if (agreementRes.isNotEmpty && startDate.isNotEmpty) {
          await _generateBackdatedRents(
            agreementRes[0]['id'].toString(),
            startDate,
            monthlyRent,
          );
        }

        // 3. Update Property Status to Occupied
        await _supabase
            .from('properties')
            .update({'status': 'Occupied'})
            .eq('id', propertyId);
      }
    } catch (e) {
      debugPrint('Error assigning tenant: $e');
      rethrow;
    }
  }

  Future<void> fixMissingRentsForUser() async {
    final user = currentUser;
    if (user == null) return;

    final agreements = await _supabase
        .from('agreements')
        .select(
          'id, start_date, monthly_rent, properties!inner(status, buildings!inner(user_id))',
        )
        .eq('properties.buildings.user_id', user.id)
        .eq('properties.status', 'Occupied');

    for (var agreement in agreements) {
      if (agreement['start_date'] != null &&
          agreement['monthly_rent'] != null) {
        await _generateBackdatedRents(
          agreement['id'].toString(),
          agreement['start_date'].toString(),
          double.tryParse(agreement['monthly_rent'].toString()) ?? 0,
        );
      }
    }
  }

  Future<void> _generateBackdatedRents(
    String agreementId,
    String startDate,
    double monthlyRent,
  ) async {
    final now = DateTime.now();
    DateTime start = DateTime.tryParse(startDate) ?? now;

    DateTime iterDate = DateTime(start.year, start.month, 1);
    DateTime currentMonthDate = DateTime(now.year, now.month, 1);

    while (iterDate.compareTo(currentMonthDate) <= 0) {
      String paymentMonth =
          '${iterDate.year}-${iterDate.month.toString().padLeft(2, '0')}';

      final existing = await _supabase
          .from('rent_payments')
          .select('id')
          .eq('agreement_id', agreementId)
          .eq('payment_month', paymentMonth);

      if (existing.isEmpty) {
        await _supabase.from('rent_payments').insert({
          'agreement_id': agreementId,
          'payment_month': paymentMonth,
          'rent_amount': monthlyRent,
          'pending_amount': monthlyRent,
          'status': 'Pending',
        });
      }

      iterDate = DateTime(iterDate.year, iterDate.month + 1, 1);
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final properties = await getProperties();
    final total = properties.length;
    final occupied = properties.where((p) => p['status'] == 'Occupied').length;
    final vacant = properties.where((p) => p['status'] == 'Vacant').length;

    return {'total': total, 'occupied': occupied, 'vacant': vacant};
  }

  // -- Rent Payments --
  Future<List<Map<String, dynamic>>> getRentPayments() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('rent_payments')
        .select(
          '*, agreements!inner(properties!inner(property_no, buildings!inner(user_id)), tenants(name))',
        )
        .eq('agreements.properties.buildings.user_id', user.id)
        .order('payment_month', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // -- Finance Overview --
  Future<Map<String, dynamic>> getFinanceOverview(String month) async {
    final user = currentUser;
    if (user == null) {
      return {
        'total_expected': 0.0,
        'total_collected': 0.0,
        'collection_rate': 0.0,
        'rent_pending_amount': 0.0,
        'rent_pending_properties': 0,
        'eb_pending_amount': 0.0,
        'eb_pending_properties': 0,
      };
    }

    // 1. Fetch properties to find active agreements and their expected rent for the given month
    final propsResponse = await _supabase
        .from('properties')
        .select(
          'id, status, agreements(id, created_at, monthly_rent, start_date, end_date), buildings!inner(user_id)',
        )
        .eq('buildings.user_id', user.id);

    Set<String> activeAgreementIds = {};
    double totalExpected = 0;

    int targetYear = int.parse(month.substring(0, 4));
    int targetMonth = int.parse(month.substring(5, 7));
    DateTime targetStart = DateTime(targetYear, targetMonth, 1);
    DateTime targetEnd = DateTime(
      targetYear,
      targetMonth + 1,
      1,
    ).subtract(const Duration(days: 1));

    for (var prop in propsResponse) {
      if (prop['agreements'] != null) {
        List agreements = List.from(prop['agreements']);
        // Sort descending by created_at so we process newest first
        agreements.sort((a, b) {
          DateTime dateA =
              DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime(2000);
          DateTime dateB =
              DateTime.tryParse(b['created_at']?.toString() ?? '') ??
              DateTime(2000);
          return dateB.compareTo(dateA);
        });

        for (var agg in agreements) {
          DateTime? startDate;
          if (agg['start_date'] != null) {
            startDate = DateTime.tryParse(agg['start_date'].toString());
          } else if (agg['created_at'] != null) {
            startDate = DateTime.tryParse(agg['created_at'].toString());
          }

          DateTime? endDate;
          if (agg['end_date'] != null) {
            endDate = DateTime.tryParse(agg['end_date'].toString());
          }

          if (startDate != null) {
            bool startValid = startDate.isBefore(
              targetEnd.add(const Duration(days: 1)),
            );
            bool endValid =
                endDate == null ||
                endDate.isAfter(targetStart.subtract(const Duration(days: 1)));
            if (startValid && endValid) {
              activeAgreementIds.add(agg['id'].toString());
              totalExpected +=
                  double.tryParse(agg['monthly_rent']?.toString() ?? '0') ?? 0;
              break; // Count only the most recent active agreement per property for that month
            }
          }
        }
      }
    }

    // 2. Get rent payments for the given month
    final rentResponse = await _supabase
        .from('rent_payments')
        .select(
          '*, agreements!inner(properties!inner(id, buildings!inner(user_id)))',
        )
        .eq('payment_month', month)
        .eq('agreements.properties.buildings.user_id', user.id);

    double totalCollected = 0;
    Set<String> fullyPaidProperties = {};

    for (var payment in rentResponse) {
      final agreementId =
          payment['agreement_id']?.toString() ??
          payment['agreements']['id']?.toString();
      if (!activeAgreementIds.contains(agreementId)) {
        continue; // Only process active agreements
      }

      double rentAmount =
          double.tryParse(payment['rent_amount']?.toString() ?? '0') ?? 0;
      double pendingAmount =
          double.tryParse(payment['pending_amount']?.toString() ?? '0') ?? 0;

      double collected = rentAmount - pendingAmount;
      if (collected > 0) {
        totalCollected += collected;
      }

      if (pendingAmount == 0 && payment['status'] == 'Paid') {
        if (payment['agreements'] != null &&
            payment['agreements']['properties'] != null) {
          fullyPaidProperties.add(
            payment['agreements']['properties']['id'].toString(),
          );
        }
      }
    }

    double rentPendingAmount = totalExpected - totalCollected;
    if (rentPendingAmount < 0) rentPendingAmount = 0;

    int rentPendingPropertiesCount =
        activeAgreementIds.length - fullyPaidProperties.length;
    double collectionRate = totalExpected > 0
        ? (totalCollected / totalExpected) * 100
        : 0;

    // 3. Attempt to fetch EB bills for the month, if table exists.
    double ebPendingAmount = 0;
    Set<String> ebPendingProperties = {};
    try {
      if (activeAgreementIds.isNotEmpty) {
        final propIds = propsResponse.map((p) => p['id']).toList();
        final ebResponse = await _supabase
            .from('eb_bills')
            .select()
            .eq('billing_month', month)
            .eq('status', 'Pending')
            .inFilter('property_id', propIds);

        for (var bill in ebResponse) {
          double amount =
              double.tryParse(bill['bill_amount']?.toString() ?? '0') ?? 0;
          ebPendingAmount += amount;
          ebPendingProperties.add(bill['property_id'].toString());
        }
      }
    } catch (e) {
      // Ignore if table doesn't exist
    }

    return {
      'total_expected': totalExpected,
      'total_collected': totalCollected,
      'collection_rate': collectionRate,
      'rent_pending_amount': rentPendingAmount,
      'rent_pending_properties': rentPendingPropertiesCount,
      'eb_pending_amount': ebPendingAmount,
      'eb_pending_properties': ebPendingProperties.length,
    };
  }

  // -- Quick Actions --

  Future<List<Map<String, dynamic>>> getPendingRentsForCurrentMonth(
    String month,
  ) async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('rent_payments')
        .select(
          '*, agreements!inner(monthly_rent, properties!inner(id, property_no, buildings!inner(name, user_id)), tenants(id, name))',
        )
        .eq('payment_month', month)
        .eq('status', 'Pending')
        .eq('agreements.properties.buildings.user_id', user.id);
    return await _filterActiveRents(List<Map<String, dynamic>>.from(response));
  }

  Future<List<Map<String, dynamic>>> getAllPastPendingRents(
    String currentMonth,
  ) async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('rent_payments')
        .select(
          '*, agreements!inner(monthly_rent, properties!inner(id, property_no, buildings!inner(name, user_id)), tenants(id, name))',
        )
        .lt('payment_month', currentMonth)
        .eq('status', 'Pending')
        .eq('agreements.properties.buildings.user_id', user.id)
        .order('payment_month', ascending: false);
    return await _filterActiveRents(List<Map<String, dynamic>>.from(response));
  }

  Future<List<Map<String, dynamic>>> _filterActiveRents(
    List<Map<String, dynamic>> rents,
  ) async {
    final user = currentUser;
    if (user == null || rents.isEmpty) return [];

    final propsResponse = await _supabase
        .from('properties')
        .select(
          'id, status, agreements(id, created_at), buildings!inner(user_id)',
        )
        .eq('buildings.user_id', user.id);

    Set<String> activeAgreementIds = {};
    for (var prop in propsResponse) {
      if (prop['status'] == 'Occupied' && prop['agreements'] != null) {
        List agreements = List.from(prop['agreements']);
        agreements.sort((a, b) {
          DateTime dateA =
              DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime(2000);
          DateTime dateB =
              DateTime.tryParse(b['created_at']?.toString() ?? '') ??
              DateTime(2000);
          if (a['created_at'] == null && a['id'] is int && b['id'] is int) {
            return (b['id'] as int).compareTo(a['id'] as int);
          }
          return dateB.compareTo(dateA);
        });
        if (agreements.isNotEmpty) {
          activeAgreementIds.add(agreements[0]['id'].toString());
        }
      }
    }

    return rents.where((rent) {
      final agreementId = rent['agreement_id']?.toString();
      return activeAgreementIds.contains(agreementId);
    }).toList();
  }

  Future<void> generateMonthlyRent() async {
    try {
      await _supabase.rpc('generate_monthly_rent_payments');
    } catch (e) {
      debugPrint('Error generating monthly rent: $e');
      rethrow;
    }
  }

  Future<void> markRentAsPaid(
    String paymentId,
    double amountPaid,
    String method,
  ) async {
    // 1. Fetch current payment details
    final payment = await _supabase
        .from('rent_payments')
        .select()
        .eq('id', paymentId)
        .single();
    double currentPending =
        double.tryParse(payment['pending_amount']?.toString() ?? '0') ?? 0;

    // 2. Calculate new pending amount
    double newPending = currentPending - amountPaid;
    if (newPending < 0) newPending = 0;

    String newStatus = newPending == 0 ? 'Paid' : 'Pending';

    // 3. Update rent_payments table
    await _supabase
        .from('rent_payments')
        .update({'pending_amount': newPending, 'status': newStatus})
        .eq('id', paymentId);

    // 4. (Optional) Record in payment_history table
    try {
      await _supabase.from('payment_history').insert({
        'rent_payment_id': paymentId,
        'amount': amountPaid,
        'payment_method': method,
        'payment_date': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Ignore if table doesn't exist
    }
  }

  Future<double?> getPreviousEBReading(String propertyId) async {
    try {
      final response = await _supabase
          .from('eb_bills')
          .select('current_reading')
          .eq('property_id', propertyId)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        return double.tryParse(
          response[0]['current_reading']?.toString() ?? '',
        );
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  Future<void> recordEB(Map<String, dynamic> data) async {
    try {
      await _supabase.from('eb_bills').insert({
        'property_id': data['property_id'],
        'billing_month': data['billing_month'],
        'previous_reading': data['previous_reading'],
        'current_reading': data['current_reading'],
        'units': data['units'],
        'bill_amount': data['bill_amount'],
        'due_date': data['due_date'],
        'status': 'Pending', // Default
      });
    } catch (e) {
      debugPrint('Error recording EB: $e');
      rethrow;
    }
  }

  Future<void> markEBBillAsPaid(String billId) async {
    try {
      await _supabase
          .from('eb_bills')
          .update({'status': 'Paid'})
          .eq('id', billId);
    } catch (e) {
      debugPrint('Error marking EB bill as paid: $e');
      rethrow;
    }
  }

  Future<void> undoMarkEBBillAsPaid(String billId) async {
    try {
      await _supabase
          .from('eb_bills')
          .update({'status': 'Pending'})
          .eq('id', billId);
    } catch (e) {
      debugPrint('Error undoing EB bill paid status: $e');
      rethrow;
    }
  }

  Future<void> recordMaintenance(Map<String, dynamic> data) async {
    try {
      await _supabase.from('maintenance_requests').insert({
        'property_id': data['property_id'],
        'issue_type': data['issue_type'],
        'description': data['description'],
        'amount': data['amount'],
        'paid_by': data['paid_by'],
        'status': data['status'],
        'date': data['date'] ?? DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error recording maintenance: $e');
      rethrow;
    }
  }

  Future<void> markMaintenanceAsPaid(String recordId) async {
    try {
      await _supabase
          .from('maintenance_requests')
          .update({'status': 'Paid'})
          .eq('id', recordId);
    } catch (e) {
      debugPrint('Error marking maintenance as paid: $e');
      rethrow;
    }
  }

  Future<void> undoMarkMaintenanceAsPaid(String recordId) async {
    try {
      await _supabase
          .from('maintenance_requests')
          .update({'status': 'Pending'})
          .eq('id', recordId);
    } catch (e) {
      debugPrint('Error undoing maintenance paid status: $e');
      rethrow;
    }
  }

  // -- Finance --

  Future<List<Map<String, dynamic>>> getAllRents() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('rent_payments')
          .select(
            '*, agreements!inner(monthly_rent, properties!inner(id, property_no, buildings!inner(user_id)), tenants(id, name))',
          )
          .eq('agreements.properties.buildings.user_id', user.id)
          .order('payment_month', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching rents: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllEBBills() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      // 1. Fetch properties for this user
      final userProps = await _supabase
          .from('properties')
          .select('id, property_no, buildings!inner(user_id)')
          .eq('buildings.user_id', user.id);

      final propIds = userProps.map((p) => p['id']).toList();
      if (propIds.isEmpty) return [];

      // 2. Fetch EB bills for those properties
      var query = _supabase
          .from('eb_bills')
          .select()
          .inFilter('property_id', propIds)
          .limit(50);

      final response = await query;

      // 3. Attach properties data locally
      final bills = List<Map<String, dynamic>>.from(response);
      for (var bill in bills) {
        final prop = userProps.firstWhere(
          (p) => p['id'] == bill['property_id'],
          orElse: () => {},
        );
        bill['properties'] = prop;
      }

      // Try to sort by created_at if it exists
      bills.sort((a, b) {
        if (a['created_at'] != null && b['created_at'] != null) {
          return DateTime.parse(
            b['created_at'],
          ).compareTo(DateTime.parse(a['created_at']));
        }
        return 0;
      });

      return bills;
    } catch (e) {
      debugPrint('Error fetching EB bills: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllMaintenanceRecords() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      // 1. Fetch properties for this user
      final userProps = await _supabase
          .from('properties')
          .select('id, property_no, buildings!inner(user_id)')
          .eq('buildings.user_id', user.id);

      final propIds = userProps.map((p) => p['id']).toList();
      if (propIds.isEmpty) return [];

      // 2. Fetch maintenance records for those properties
      var query = _supabase
          .from('maintenance_requests')
          .select()
          .inFilter('property_id', propIds)
          .limit(50);

      final response = await query;

      // 3. Attach properties data locally
      final records = List<Map<String, dynamic>>.from(response);
      for (var record in records) {
        final prop = userProps.firstWhere(
          (p) => p['id'] == record['property_id'],
          orElse: () => {},
        );
        record['properties'] = prop;
      }

      // Try to sort by created_at if it exists
      records.sort((a, b) {
        if (a['created_at'] != null && b['created_at'] != null) {
          return DateTime.parse(
            b['created_at'],
          ).compareTo(DateTime.parse(a['created_at']));
        }
        return 0;
      });

      return records;
    } catch (e) {
      debugPrint('Error fetching maintenance records: $e');
      return [];
    }
  }

  // -- Reminders --

  Future<List<Map<String, dynamic>>> getReminders() async {
    final user = currentUser;
    if (user == null) return [];

    List<Map<String, dynamic>> reminders = [];
    final now = DateTime.now();

    try {
      // 1. Pending Rents
      final rents = await _supabase
          .from('rent_payments')
          .select(
            'payment_month, agreements!inner(properties!inner(property_no, buildings!inner(user_id)))',
          )
          .eq('status', 'Pending')
          .eq('agreements.properties.buildings.user_id', user.id);

      for (var rent in rents) {
        final prop =
            rent['agreements']?['properties']?['property_no'] ?? 'Unknown';
        final month = rent['payment_month'] ?? '';
        reminders.add({
          'title': 'Overdue: Rent pending for $month',
          'prop': prop,
          'type': 'critical',
          'icon_type': 'rent',
        });
      }

      // 2. Pending EB Bills
      final ebBills = await _supabase
          .from('eb_bills')
          .select(
            'due_date, properties!inner(property_no, buildings!inner(user_id))',
          )
          .eq('status', 'Pending')
          .eq('properties.buildings.user_id', user.id);

      for (var bill in ebBills) {
        final prop = bill['properties']?['property_no'] ?? 'Unknown';
        if (bill['due_date'] != null) {
          final dueDate = DateTime.tryParse(bill['due_date']);
          if (dueDate != null) {
            final diff = dueDate.difference(now).inDays;
            if (diff < 0) {
              reminders.add({
                'title': 'Overdue: EB payment',
                'prop': prop,
                'type': 'critical',
                'icon_type': 'eb',
              });
            } else if (diff <= 3) {
              reminders.add({
                'title': 'EB payment due in $diff days',
                'prop': prop,
                'type': 'warning',
                'icon_type': 'eb',
              });
            }
          }
        }
      }

      // 3. Agreement Expirations
      final agreements = await _supabase
          .from('agreements')
          .select(
            'end_date, properties!inner(property_no, buildings!inner(user_id))',
          )
          .eq('properties.buildings.user_id', user.id);

      for (var agreement in agreements) {
        final prop = agreement['properties']?['property_no'] ?? 'Unknown';
        if (agreement['end_date'] != null) {
          final endDate = DateTime.tryParse(agreement['end_date']);
          if (endDate != null) {
            final diff = endDate.difference(now).inDays;
            if (diff < 0) {
              reminders.add({
                'title': 'Overdue: Rental agreement expired',
                'prop': prop,
                'type': 'critical',
                'icon_type': 'agreement',
              });
            } else if (diff >= 0 && diff <= 30) {
              reminders.add({
                'title': 'Rental agreement expires in $diff days',
                'prop': prop,
                'type': 'upcoming',
                'icon_type': 'agreement',
              });
            }
          }
        }
      }

      // 4. Lending Reminders (Principal & Interest)
      final lendings = await _supabase
          .from('investments')
          .select('*, investment_transactions(*)')
          .eq('user_id', user.id)
          .eq('type', 'Lending')
          .eq('status', 'Active');

      for (var lending in lendings) {
        final borrower = lending['title'] ?? 'Unknown Borrower';

        // A. Principal Repayment Reminder
        if (lending['end_date'] != null) {
          final endDate = DateTime.tryParse(lending['end_date']);
          if (endDate != null) {
            final diff = endDate.difference(now).inDays;
            if (diff < 0) {
              reminders.add({
                'title': 'Overdue: Lending repayment from $borrower',
                'prop': 'Principal: ₹${lending['principal_amount']}',
                'type': 'critical',
                'icon_type': 'finance',
              });
            } else if (diff >= 0 && diff <= 30) {
              reminders.add({
                'title': 'Lending repayment from $borrower due in $diff days',
                'prop': 'Principal: ₹${lending['principal_amount']}',
                'type': 'upcoming',
                'icon_type': 'finance',
              });
            }
          }
        }

        // B. Pending Interest Reminder
        final principal =
            double.tryParse(lending['principal_amount']?.toString() ?? '0') ??
            0;
        final rate =
            double.tryParse(lending['interest_rate']?.toString() ?? '0') ?? 0;

        final transactions = lending['investment_transactions'] as List? ?? [];
        double totalPrincipalPaid = 0;
        double totalInterestReceived = 0;

        for (var p in transactions) {
          if (p['transaction_type'] == 'Principal Repayment') {
            totalPrincipalPaid +=
                double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
          } else if (p['transaction_type'] == 'Interest') {
            totalInterestReceived +=
                double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
          } else if (p['transaction_type'] == 'Settlement') {
            double amount =
                double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
            double settledInterest = amount - principal;
            if (settledInterest > 0) totalInterestReceived += settledInterest;
          }
        }

        double remainingPrincipal = principal - totalPrincipalPaid;
        double expectedMonthlyInterest = remainingPrincipal * (rate / 100) / 12;

        final startDate =
            DateTime.tryParse(lending['start_date']?.toString() ?? '') ?? now;
        int monthsPassed =
            (now.year - startDate.year) * 12 + now.month - startDate.month;
        if (now.day >= startDate.day) {
          monthsPassed++;
        }
        if (monthsPassed < 1) monthsPassed = 1;

        double pendingInterest =
            (monthsPassed * expectedMonthlyInterest) - totalInterestReceived;

        if (pendingInterest > 0.5) {
          reminders.add({
            'title': 'Overdue: Interest from $borrower',
            'prop': 'Pending: ₹${pendingInterest.toStringAsFixed(0)}',
            'type': 'critical',
            'icon_type': 'finance',
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching reminders: $e');
    }

    return reminders;
  }

  // -- Recent Activity --
  Future<List<Map<String, dynamic>>> getRecentActivity() async {
    final user = currentUser;
    if (user == null) return [];

    List<Map<String, dynamic>> activities = [];

    try {
      // 1. Rent Payments (Paid)
      final rents = await _supabase
          .from('rent_payments')
          .select(
            '*, agreements!inner(properties!inner(property_no, buildings!inner(user_id)))',
          )
          .eq('status', 'Paid')
          .eq('agreements.properties.buildings.user_id', user.id)
          .limit(5);

      for (var rent in rents) {
        final prop =
            rent['agreements']?['properties']?['property_no'] ?? 'Unknown';
        final amount =
            rent['rent_amount'] ?? rent['agreements']?['monthly_rent'] ?? 0;
        activities.add({
          'type': 'rent',
          'title': 'Rent Collected',
          'amount': '+$amount',
          'subtitle': prop,
          'date':
              rent['payment_month'] ??
              '', // Using payment_month as proxy for date
          'timestamp': DateTime.now()
              .toIso8601String(), // Fallback for sorting if no created_at
        });
      }

      // 2. EB Bills
      final ebBills = await _supabase
          .from('eb_bills')
          .select('*, properties!inner(property_no, buildings!inner(user_id))')
          .eq('properties.buildings.user_id', user.id)
          .order('created_at', ascending: false)
          .limit(5);

      for (var bill in ebBills) {
        final prop = bill['properties']?['property_no'] ?? 'Unknown';
        final amount = bill['bill_amount'] ?? 0;
        final status = bill['status'] ?? 'Pending';

        activities.add({
          'type': 'eb',
          'title': status == 'Paid' ? 'EB Payment Collected' : 'EB Bill Added',
          'amount': status == 'Paid' ? '+$amount' : '$amount',
          'subtitle': prop,
          'date': 'Recent',
          'timestamp': bill['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }

      // 3. Maintenance
      final maintenance = await _supabase
          .from('maintenance_requests')
          .select('*, properties!inner(property_no, buildings!inner(user_id))')
          .eq('properties.buildings.user_id', user.id)
          .order('created_at', ascending: false)
          .limit(5);

      for (var req in maintenance) {
        final prop = req['properties']?['property_no'] ?? 'Unknown';
        final amount = req['amount'] ?? 0;
        final status = req['status'] ?? 'Pending';
        final paidBy = req['paid_by'] ?? 'Owner';

        String amountStr;
        if (paidBy == 'Tenant') {
          amountStr = status == 'Paid' ? '+$amount' : '₹$amount';
        } else {
          amountStr = '-$amount';
        }

        activities.add({
          'type': 'maintenance',
          'title': 'Maintenance Added',
          'amount': amountStr,
          'subtitle': prop,
          'date': req['date'] != null
              ? req['date'].toString().split('T')[0]
              : 'Recent',
          'timestamp': req['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }

      // Sort by timestamp descending
      activities.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['timestamp']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            DateTime.tryParse(b['timestamp']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    } catch (e) {
      debugPrint('Error fetching recent activity: $e');
    }

    // Return top 5
    return activities.take(5).toList();
  }

  // -- Property History --
  Future<List<Map<String, dynamic>>> getPropertyHistory(
    String propertyId, {
    String? activeAgreementId,
  }) async {
    List<Map<String, dynamic>> history = [];

    try {
      // 1. Rent Payments
      var rentQuery = _supabase
          .from('rent_payments')
          .select('*, agreements!inner(property_id, monthly_rent)');

      if (activeAgreementId != null) {
        rentQuery = rentQuery.eq('agreement_id', activeAgreementId);
      } else {
        rentQuery = rentQuery.eq('agreements.property_id', propertyId);
      }

      final rents = await rentQuery;

      for (var rent in rents) {
        final status = rent['status'] ?? 'Unknown';
        if (status != 'Paid') {
          continue; // Only show Paid transactions in history
        }

        final amount =
            rent['rent_amount'] ?? rent['agreements']?['monthly_rent'] ?? 0;
        history.add({
          'type': 'rent',
          'title': status == 'Paid' ? 'Rent Collected' : 'Rent Pending',
          'amount': status == 'Paid' ? '+$amount' : '₹$amount',
          'subtitle': 'Month: ${rent['payment_month'] ?? ''}',
          'status': status,
          'timestamp': rent['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }

      // 2. EB Bills
      final ebBills = await _supabase
          .from('eb_bills')
          .select('*')
          .eq('property_id', propertyId);

      for (var bill in ebBills) {
        final status = bill['status'] ?? 'Unknown';
        if (status != 'Paid') {
          continue; // Only show Paid transactions in history
        }

        final amount = bill['bill_amount'] ?? 0;
        history.add({
          'type': 'eb',
          'title': 'EB Bill',
          'amount': status == 'Paid' ? '-$amount' : '₹$amount',
          'subtitle':
              'Month: ${bill['billing_month'] ?? ''} (${bill['units']} Units)',
          'status': status,
          'timestamp': bill['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }

      // 3. Maintenance
      final maintenance = await _supabase
          .from('maintenance_requests')
          .select('*')
          .eq('property_id', propertyId);

      for (var req in maintenance) {
        final status = req['status'] ?? 'Pending';
        if (status != 'Paid') {
          continue; // Only show Paid transactions in history
        }

        final amount = req['amount'] ?? 0;
        final paidBy = req['paid_by'] ?? 'Owner';

        String amountStr;
        if (paidBy == 'Tenant') {
          amountStr = status == 'Paid' ? '+$amount' : '₹$amount';
        } else {
          amountStr = '-$amount';
        }

        history.add({
          'type': 'maintenance',
          'title': req['issue_description'] ?? 'Maintenance',
          'amount': amountStr,
          'subtitle': 'Date: ${req['date'] ?? ''}',
          'status': status,
          'timestamp': req['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }

      // Sort by timestamp descending
      history.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['timestamp']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            DateTime.tryParse(b['timestamp']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    } catch (e) {
      debugPrint('Error fetching property history: $e');
    }

    return history;
  }

  // -- Pending Dues --
  Future<List<Map<String, dynamic>>> getPendingDues(
    String propertyId, {
    String? activeAgreementId,
  }) async {
    List<Map<String, dynamic>> dues = [];
    try {
      // Include rent dues as well
      var rentQuery = _supabase
          .from('rent_payments')
          .select('*, agreements!inner(property_id)')
          .eq('status', 'Pending');

      if (activeAgreementId != null) {
        rentQuery = rentQuery.eq('agreement_id', activeAgreementId);
      } else {
        rentQuery = rentQuery.eq('agreements.property_id', propertyId);
      }

      final rents = await rentQuery;

      for (var rent in rents) {
        dues.add({
          'type': 'rent',
          'title': 'Rent Pending',
          'subtitle': 'Month: ${rent['payment_month'] ?? ''}',
          'amount':
              double.tryParse(rent['pending_amount']?.toString() ?? '0') ?? 0,
        });
      }

      final ebs = await _supabase
          .from('eb_bills')
          .select('*')
          .eq('property_id', propertyId)
          .eq('status', 'Pending');

      for (var eb in ebs) {
        dues.add({
          'type': 'eb',
          'title': 'EB Bill Pending',
          'subtitle': 'Month: ${eb['billing_month'] ?? ''}',
          'amount': double.tryParse(eb['bill_amount']?.toString() ?? '0') ?? 0,
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending dues: $e');
    }
    return dues;
  }

  // -- Agreement Management --
  Future<void> updateAgreementRent({
    required String agreementId,
    required double newRent,
    required double newAdvance,
  }) async {
    try {
      await _supabase
          .from('agreements')
          .update({'monthly_rent': newRent, 'advance_amount': newAdvance})
          .eq('id', agreementId);
    } catch (e) {
      debugPrint('Error updating agreement rent: $e');
      rethrow;
    }
  }

  Future<void> renewAgreement({
    required String oldAgreementId,
    required String propertyId,
    required String tenantId,
    required double monthlyRent,
    required double advanceAmount,
    required String startDate,
    required String endDate,
  }) async {
    try {
      // Note: Assuming 'status' is not needed in agreements anymore since it causes schema cache errors.
      // await _supabase.from('agreements').update({
      //   'status': 'Renewed',
      // }).eq('id', oldAgreementId);

      // 2. Insert new agreement
      await _supabase.from('agreements').insert({
        'property_id': propertyId,
        'tenant_id': tenantId,
        'start_date': startDate,
        'end_date': endDate,
        'monthly_rent': monthlyRent,
        'advance_amount': advanceAmount,
      });
    } catch (e) {
      debugPrint('Error renewing agreement: $e');
      rethrow;
    }
  }

  Future<void> vacateProperty({
    required String agreementId,
    required String propertyId,
    double? totalDuesDeducted,
    double? settlementAmount,
  }) async {
    try {
      // 1. Mark agreement's end_date to today and save settlement
      final today = DateTime.now().toIso8601String().split('T')[0];

      final Map<String, dynamic> updateData = {'end_date': today};

      // Note: Removed to fix PGRST204 schema cache error as these columns don't exist
      // if (totalDuesDeducted != null) {
      //   updateData['total_dues_deducted'] = totalDuesDeducted;
      // }
      // if (settlementAmount != null) {
      //   updateData['settlement_amount'] = settlementAmount;
      // }

      await _supabase
          .from('agreements')
          .update(updateData)
          .eq('id', agreementId);

      // 2. Mark property as 'Vacant'
      await _supabase
          .from('properties')
          .update({'status': 'Vacant'})
          .eq('id', propertyId);

      // 3. Mark all pending rent payments for this agreement as Paid (since they are deducted from advance)
      await _supabase
          .from('rent_payments')
          .update({'status': 'Paid'})
          .eq('agreement_id', agreementId)
          .eq('status', 'Pending');

      // 4. Mark all pending EB bills for this property as Paid (since they are deducted from advance)
      // Note: We use property_id here because EB bills don't track agreement_id
      await _supabase
          .from('eb_bills')
          .update({'status': 'Paid'})
          .eq('property_id', propertyId)
          .eq('status', 'Pending');
    } catch (e) {
      debugPrint('Error vacating property: $e');
      rethrow;
    }
  }

  // ==========================================
  // INVESTMENTS MODULE
  // ==========================================

  Future<void> addInvestment(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user != null) {
      data['user_id'] = user.id;
    }
    try {
      await _supabase.from('investments').insert(data);
    } catch (e) {
      debugPrint('Error adding investment: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getInvestments() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('investments')
          .select('*, investment_transactions(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching investments: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getInvestmentDetails(String id) async {
    try {
      final response = await _supabase
          .from('investments')
          .select('*, investment_transactions(*)')
          .eq('id', id)
          .single();
      return response;
    } catch (e) {
      debugPrint('Error fetching investment details: $e');
      rethrow;
    }
  }

  Future<void> recordInvestmentTransaction(Map<String, dynamic> data) async {
    try {
      await _supabase.from('investment_transactions').insert(data);
    } catch (e) {
      debugPrint('Error recording investment transaction: $e');
      rethrow;
    }
  }

  Future<void> closeInvestment(String id) async {
    try {
      await _supabase
          .from('investments')
          .update({'status': 'Closed'})
          .eq('id', id);
    } catch (e) {
      debugPrint('Error closing investment: $e');
      rethrow;
    }
  }

  Future<void> updateInvestment(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('investments').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating investment: $e');
      rethrow;
    }
  }

  Future<void> deleteInvestment(String id) async {
    try {
      await _supabase.from('investments').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting investment: $e');
      rethrow;
    }
  }
  // -- Financial Reminders --

  Future<List<Map<String, dynamic>>> getFinancialReminders() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('financial_reminders')
          .select()
          .eq('user_id', user.id)
          .order('due_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching financial reminders: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> addFinancialReminder(
    Map<String, dynamic> data,
  ) async {
    final user = currentUser;
    if (user != null) {
      data['user_id'] = user.id;
    }

    try {
      final response = await _supabase
          .from('financial_reminders')
          .insert(data)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error adding financial reminder: $e');
      rethrow;
    }
  }

  Future<void> updateFinancialReminder(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _supabase.from('financial_reminders').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating financial reminder: $e');
      rethrow;
    }
  }

  Future<void> deleteFinancialReminder(String id) async {
    try {
      await _supabase.from('financial_reminders').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting financial reminder: $e');
      rethrow;
    }
  }
}
