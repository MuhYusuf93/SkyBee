import 'package:sqflite/sqflite.dart';
import 'package:dlibphonenumber/dlibphonenumber.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/contact_validation.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/repositories/keyset_queries.dart';
import '../domain/member_models.dart';

/// Shared transaction-bound member rules. This helper never opens a database,
/// grants access, writes a sale, or merges records based on a matching name.
final class MemberRules {
  /// Shared bounded prefix matching for owner/member selection and old debts.
  /// Raw legacy phones remain searchable even when they need owner repair.
  static SqlQuery searchWhere(String input, String region) {
    final q = normalizeName(input);
    if (q.length > 200) throw const AppError('m53MemberFieldsInvalid');
    if (q.isEmpty) return const SqlQuery('1=1', []);
    final conditions = <String>[], args = <Object?>[];
    void prefix(String column, String value) {
      final end = prefixEnd(value);
      conditions.add(
        '($column COLLATE BINARY>=? ${end == null ? '' : 'AND $column COLLATE BINARY<?'})',
      );
      args.addAll([value, ?end]);
    }

    prefix('c.normalized_name', q);
    final phone = searchPhone(input, region);
    if (phone != null) prefix('c.phone_e164', phone);
    if (RegExp(r'^\+?[0-9][0-9\s()-]*$').hasMatch(input.trim())) {
      prefix('c.phone_number', input.trim());
    }
    return SqlQuery('(${conditions.join(' OR ')})', args);
  }

  /// A search prefix uses shop phone metadata, independently from currency/UI.
  /// Full numbers first use exactly the same canonical parser as member writes.
  static String? searchPhone(String input, String region) {
    final raw = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(raw) || raw.length > 32) return null;
    try {
      return ContactValidation.phone(raw, region: region);
    } on AppError {
      if (raw.startsWith('+')) return raw;
      final util = PhoneNumberUtil.instance;
      final country = util.getCountryCodeForRegion(region);
      if (country == 0) return null;
      final trunk = util.getNddPrefixForRegion(region, true);
      final national =
          trunk != null && trunk.isNotEmpty && raw.startsWith(trunk)
          ? raw.substring(trunk.length)
          : raw;
      return '+$country$national';
    }
  }

  static ({String name, String phone, String address}) normalize(
    MemberInput input,
    String region,
  ) {
    final name = input.name.trim(), address = input.address.trim();
    if (name.isEmpty || name.length > 200 || address.length > 4096) {
      throw const AppError('m53MemberFieldsInvalid');
    }
    if (input.phone.trim().isEmpty) {
      throw const AppError('m53MemberPhoneRequired');
    }
    if (input.phone.length > 128) throw const AppError('m52PhoneInvalid');
    final phone = ContactValidation.phone(input.phone, region: region)!;
    return (name: name, phone: phone, address: address);
  }

  static Future<void> requireUnique(
    DatabaseExecutor db,
    String phone, {
    EntityId? except,
  }) async {
    final matches = await db.rawQuery(
      '''SELECT 1 FROM customers
      WHERE phone_e164=? ${except == null ? '' : 'AND id<>?'} LIMIT 1''',
      [phone, if (except != null) except.value],
    );
    if (matches.isNotEmpty) throw const AppError('m53MemberPhoneUsed');
  }

  /// Old debt repayment and explicitly selected paid sales retain legacy IDs.
  /// New credit rechecks current completeness and uniqueness.
  static Future<ResolvedMember> existingOn(
    DatabaseExecutor db,
    EntityId id, {
    bool requireComplete = true,
  }) async {
    final rows = await db.rawQuery(
      '''SELECT id,name,phone_e164,is_deleted,
      member_phone_region,CASE WHEN typeof(phone_number)='text' AND length(phone_number)<=128
      THEN phone_number END AS phone_number FROM customers WHERE id=?''',
      [id.value],
    );
    if (rows.isEmpty || rows.single['is_deleted'] != 0) {
      throw const AppError('m3CustomerUnavailable');
    }
    final row = rows.single;
    final phone = row['phone_e164'] as String?;
    if (!requireComplete) {
      return ResolvedMember(
        id,
        row['name'] as String,
        phone ?? row['phone_number'] as String?,
      );
    }
    if (phone == null) throw const AppError('m53MemberRepairRequired');
    try {
      if (ContactValidation.phone(
            row['phone_number'] as String?,
            region: row['member_phone_region'] as String,
          ) !=
          phone) {
        throw const AppError('m53MemberRepairRequired');
      }
    } on AppError {
      throw const AppError('m53MemberRepairRequired');
    }
    try {
      await requireUnique(db, phone, except: id);
    } on AppError catch (e) {
      if (e.message != 'm53MemberPhoneUsed') rethrow;
      throw const AppError('m53MemberRepairRequired');
    }
    return ResolvedMember(id, row['name'] as String, phone);
  }

  static Future<ResolvedMember> createOn(
    DatabaseExecutor db,
    EntityId id,
    MemberInput input,
    String region,
    int now,
  ) async {
    final values = normalize(input, region);
    await requireUnique(db, values.phone);
    await db.insert('customers', {
      'id': id.value,
      'name': values.name,
      'normalized_name': normalizeName(values.name),
      'phone_number': values.phone,
      'phone_e164': values.phone,
      'member_phone_region': region,
      'profile_version': 1,
      'address': values.address,
      'revision': 0,
      'created_at': now,
      'updated_at': now,
    });
    return ResolvedMember(id, values.name, values.phone);
  }
}
