import 'dart:typed_data';
import '../../../core/utils/id_generator.dart';
import '../../../core/month_scope/accounting_month_scope.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TravelerRemoteDataSourceImpl {
  TravelerRemoteDataSourceImpl(this.client);
  final SupabaseClient client;
  Future<List<Map<String, dynamic>>> list(String query) async {
    const pageSize = 500;
    final month = AccountingMonthScope.start;
    final monthStart =
        '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
    final allRows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final result = await client.rpc(
        'sws_list_travelers',
        params: {
          'p_search': query.trim().isEmpty ? null : query.trim(),
          'p_limit': pageSize,
          'p_offset': offset,
          'p_month_start': monthStart,
        },
      );
      if (result is! List) {
        throw const FormatException('Invalid traveler list response');
      }
      final rows = result
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      allRows.addAll(rows);
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return allRows;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final result = await client.rpc(
      'sws_create_traveler',
      params: {
        'p_full_name': data['full_name'],
        'p_phone': data['phone'],
        'p_agreement_total': data['agreement_total'],
        'p_sales_person': data['sales_person'],
        'p_country': data['destination_country'],
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> updateTraveler(Map<String, dynamic> data) async {
    final result = await client.rpc(
      'sws_update_traveler',
      params: {
        'p_traveler_id': data['id'],
        'p_full_name': data['full_name'],
        'p_phone': data['phone'],
        'p_agreement_total': data['agreement_total'],
        'p_sales_person': data['sales_person'],
        'p_country': data['destination_country'],
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<bool> get isHr async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    final profile = await client
        .from('profiles')
        .select('role,is_active')
        .eq('user_id', user.id)
        .maybeSingle();
    return profile != null &&
        profile['role'] == 'hr' &&
        profile['is_active'] == true;
  }

  Future<Map<String, dynamic>> getTraveler(String id) async {
    final row = Map<String, dynamic>.from(
      await client.from('travelers').select('*').eq('id', id).single(),
    );
    final total = await client.rpc(
      'sws_get_traveler_paid_total',
      params: {'p_traveler_id': id},
    );
    final paid = total is num
        ? total.toDouble()
        : double.tryParse('$total') ?? 0;
    return {...row, 'paid_amount': paid};
  }

  Future<List<Map<String, dynamic>>> payments(String id) async {
    if (await isHr) return <Map<String, dynamic>>[];
    final rows = await client
        .from('financial_movements')
        .select()
        .eq('traveler_id', id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> documents(String id) async {
    final rows = await client
        .from('traveler_documents')
        .select()
        .eq('traveler_id', id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addPayment(Map<String, dynamic> movement) async {
    await client.rpc(
      'sws_record_traveler_payment',
      params: {
        'p_traveler_id': movement['traveler_id'],
        'p_amount': movement['amount'],
        'p_payment_method': movement['payment_method'],
        'p_note': movement['note'],
        'p_idempotency_key': IdGenerator.uuidV4(),
      },
    );
  }

  Future<void> archiveTraveler(String travelerId, String reason) async {
    await client.rpc(
      'sws_archive_traveler',
      params: {'p_traveler_id': travelerId, 'p_reason': reason},
    );
  }

  Future<bool> deleteTraveler(String travelerId, String reason) async {
    await client.rpc(
      'sws_delete_traveler',
      params: {'p_traveler_id': travelerId, 'p_reason': reason},
    );
    return cleanupPendingStorage();
  }

  Future<bool> cleanupPendingStorage() async {
    final response = await client.rpc('sws_list_pending_storage_cleanup');
    final paths = (response as List? ?? const [])
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (paths.isEmpty) return true;
    try {
      await client.storage.from('sws-private-documents').remove(paths);
      await client.rpc(
        'sws_ack_storage_cleanup',
        params: {'p_storage_paths': paths},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setStage(String travelerId, String stage, bool value) async {
    await client.rpc(
      'sws_set_traveler_stage',
      params: {'p_traveler_id': travelerId, 'p_stage': stage, 'p_value': value},
    );
  }

  Future<void> setTicketBooking(
    String travelerId,
    String? type,
    String? note,
  ) async {
    await client.rpc(
      'sws_set_traveler_ticket_booking',
      params: {
        'p_traveler_id': travelerId,
        'p_booking_type': type,
        'p_note': note,
      },
    );
  }

  Future<void> setAvatar(
    String travelerId,
    String fileName,
    String mimeType,
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty) throw ArgumentError('Empty avatar image');
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        'traveler-avatars/$travelerId/${DateTime.now().microsecondsSinceEpoch}_$safe';
    const bucket = 'sws-private-documents';
    String? previousPath;
    try {
      final previous = await client
          .from('travelers')
          .select('avatar_path')
          .eq('id', travelerId)
          .maybeSingle();
      previousPath = previous?['avatar_path']?.toString();
    } catch (_) {
      /* A previous image is optional; do not block a new upload. */
    }
    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    try {
      await client.rpc(
        'sws_set_traveler_avatar',
        params: {'p_traveler_id': travelerId, 'p_avatar_path': path},
      );
    } catch (_) {
      try {
        await client.storage.from(bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
    if (previousPath != null &&
        previousPath.startsWith('traveler-avatars/$travelerId/')) {
      try {
        await client.storage.from(bucket).remove([previousPath]);
      } catch (_) {
        /* Keep the new avatar; cleanup can be retried. */
      }
    }
  }
}

typedef TravelerRemoteDataSource = TravelerRemoteDataSourceImpl;
