part of 'supplier_service.dart';

extension SupplierVisits on SupplierService {
  /// Nearest planned calendar date, independently of past rows on the first
  /// history page. Both existing supplier/global calendar indexes cover it.
  Future<CalendarDate?> nextVisitDay({EntityId? supplier}) => _read((db) async {
    final today = await _todayOn(db);
    final rows = await db.query(
      'supplier_visits',
      columns: ['visit_date'],
      where:
          "status='planned' AND visit_date>=? ${supplier == null ? '' : 'AND supplier_id=?'}",
      whereArgs: [today.iso, if (supplier != null) supplier.value],
      orderBy: 'visit_date,id COLLATE BINARY',
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : CalendarDate(rows.single['visit_date'] as String);
  });
  Future<bool> reminderUnavailable({EntityId? supplier}) => _read((db) async {
    final owner = access.role == ManagementRole.owner;
    final rows = await db.rawQuery(
      '''SELECT 1 FROM supplier_reminder_jobs j WHERE j.active=1 AND j.error_code IS NOT NULL AND
      ((j.kind='visit' AND EXISTS(SELECT 1 FROM supplier_visits v WHERE v.id=j.source_id ${supplier == null ? '' : 'AND v.supplier_id=?'}))
      ${owner ? "OR (j.kind='due' AND EXISTS(SELECT 1 FROM supplier_invoices i WHERE i.id=j.source_id ${supplier == null ? '' : 'AND i.supplier_id=?'}))" : ''}) LIMIT 1''',
      [
        if (supplier != null) supplier.value,
        if (owner && supplier != null) supplier.value,
      ],
    );
    return rows.isNotEmpty;
  });
  Future<SupplierVisitCalendar> visitCalendar() => _read(
    (db) async => SupplierVisitCalendar(
      (await db.query(
            'store_settings',
            columns: ['time_zone'],
          )).single['time_zone']
          as String,
      access.clock.now,
    ),
  );
  Future<Page<Map<String, Object?>, SupplierVisitCursor>> dueReminderInvoices({
    EntityId? supplier,
    SupplierVisitCursor? after,
  }) => _ownerRead((db) async {
    if (after != null &&
        (after.supplier != supplier ||
            after.status != 'due' ||
            after.generation != database.generation ||
            after.revision != database.revision)) {
      throw const AppError('m53VisitChanged');
    }
    final rows = await db.rawQuery(
      '''WITH invoices AS(${SupplierService._invoiceSelect}) SELECT * FROM invoices WHERE status='posted' AND effective_due IS NOT NULL AND total_minor-paid_minor-credit_minor>0 ${supplier == null ? '' : 'AND supplier_id=?'} ${after == null ? '' : 'AND (effective_due,id)>(?,?)'} ORDER BY effective_due,id COLLATE BINARY LIMIT 21''',
      [
        if (supplier != null) supplier.value,
        if (after != null) ...[after.date, after.id.value],
      ],
    );
    final page = rows.take(20).toList();
    return Page(
      items: page,
      nextCursor: rows.length <= 20
          ? null
          : SupplierVisitCursor(
              supplier,
              'due',
              page.last['effective_due'] as String,
              EntityId(page.last['id'] as String),
              database.generation,
              database.revision,
            ),
    );
  });
  Future<SupplierVisit> visit(EntityId id) => _read((db) => _visitOn(db, id));
  static Future<SupplierVisit> _visitOn(
    DatabaseExecutor db,
    EntityId id,
  ) async {
    final rows = await db.query(
      'supplier_visits',
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (rows.length != 1) throw const AppError('m53VisitMissing');
    return SupplierVisit(rows.single);
  }

  /// A visit plan changes no stock, invoice due date or payment. Revision events
  /// retain earlier dates/statuses even when the current projection changes.
  Future<SupplierVisit> saveVisit(
    EntityId supplier,
    SupplierVisitInput input, {
    EntityId? id,
    int expectedRevision = 0,
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    if (!const ['planned', 'completed', 'cancelled'].contains(input.status) ||
        input.timeMinutes != null &&
            (input.timeMinutes! < 0 || input.timeMinutes! > 1439)) {
      throw const AppError('m53VisitInputInvalid');
    }
    final note = SupplierService.optional(input.note, 1000);
    final hash = SupplierService.fingerprint([
      supplier.value,
      id?.value,
      expectedRevision,
      input.fingerprint,
    ]);
    final prior = await db.query(
      'supplier_visit_events',
      where: 'operation_key=?',
      whereArgs: [operationKey],
    );
    if (prior.isNotEmpty) {
      if (prior.single['payload_hash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return _visitOn(db, EntityId(prior.single['visit_id'] as String));
    }
    final masters = await db.query(
      'suppliers',
      where: 'id=?',
      whereArgs: [supplier.value],
    );
    if (masters.length != 1 ||
        id == null && masters.single['is_deleted'] != 0) {
      throw const AppError('m53SupplierMissing');
    }
    final old = id == null ? null : await _visitOn(db, id);
    if (old?.supplier != null && old!.supplier != supplier ||
        (old?.revision ?? 0) != expectedRevision) {
      throw const AppError('m53VisitChanged');
    }
    final visitId = id ?? SupplierService._ids.next(),
        now = access.clock.milliseconds;
    final snapshot = <String, Object?>{
      'supplier_name': masters.single['name'],
      'visit_date': input.date.iso,
      'time_minutes': input.timeMinutes,
      'note': note,
      'status': input.status,
      'reminder': input.reminder ? 1 : 0,
    };
    if (old == null) {
      await db.insert('supplier_visits', {
        'id': visitId.value,
        'supplier_id': supplier.value,
        ...snapshot,
        'revision': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    await db.insert('supplier_visit_events', {
      'id': SupplierService._ids.next().value,
      'visit_id': visitId.value,
      'revision': expectedRevision + 1,
      ...snapshot,
      'operation_key': operationKey,
      'payload_hash': hash,
      'actor_role': access.role!.name,
      'created_at': now,
    });
    if (old != null) {
      await db.update(
        'supplier_visits',
        {...snapshot, 'revision': expectedRevision + 1, 'updated_at': now},
        where: 'id=? AND revision=?',
        whereArgs: [visitId.value, expectedRevision],
      );
    }
    await access.audit(db, 'supplier_visit_saved', entityId: visitId.value);
    return _visitOn(db, visitId);
  });

  Future<Page<SupplierVisit, SupplierVisitCursor>> visits({
    EntityId? supplier,
    String? status = 'planned',
    SupplierVisitCursor? after,
  }) => _read((db) async {
    if (status != null &&
        !const ['planned', 'completed', 'cancelled'].contains(status)) {
      throw const AppError('m53VisitInputInvalid');
    }
    if (after != null &&
        (after.supplier != supplier ||
            after.status != status ||
            after.generation != database.generation ||
            after.revision != database.revision)) {
      throw const AppError('m53VisitChanged');
    }
    final rows = await db.rawQuery(
      '''SELECT * FROM supplier_visits WHERE 1=1 ${supplier == null ? '' : 'AND supplier_id=?'} ${status == null ? '' : 'AND status=?'} ${after == null ? '' : 'AND (visit_date,id)>(?,?)'} ORDER BY visit_date,id COLLATE BINARY LIMIT 21''',
      [
        if (supplier != null) supplier.value,
        ?status,
        if (after != null) ...[after.date, after.id.value],
      ],
    );
    final page = rows.take(20).map(SupplierVisit.new).toList();
    return Page(
      items: page,
      nextCursor: rows.length <= 20
          ? null
          : SupplierVisitCursor(
              supplier,
              status,
              page.last.date.iso,
              page.last.id,
              database.generation,
              database.revision,
            ),
    );
  });

  static Future<SupplierInvoiceReminder> reminderOn(
    DatabaseExecutor db,
    EntityId id,
  ) async {
    final rows = await db.query(
      'supplier_invoice_reminder_events',
      where: 'invoice_id=?',
      whereArgs: [id.value],
      orderBy: 'revision DESC',
      limit: 1,
    );
    return rows.isEmpty
        ? const SupplierInvoiceReminder(true, 0)
        : SupplierInvoiceReminder(
            rows.single['enabled'] == 1,
            rows.single['revision'] as int,
          );
  }

  Future<SupplierInvoiceReminder> invoiceReminder(EntityId id) =>
      _ownerRead((db) async {
        await SupplierService.invoiceOn(db, id);
        return reminderOn(db, id);
      });
  Future<SupplierInvoiceReminder> setInvoiceReminder(
    EntityId id,
    bool enabled,
    int expectedRevision, {
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final hash = SupplierService.fingerprint([
      id.value,
      enabled,
      expectedRevision,
    ]);
    final prior = await db.query(
      'supplier_invoice_reminder_events',
      where: 'operation_key=?',
      whereArgs: [operationKey],
    );
    if (prior.isNotEmpty) {
      if (prior.single['payload_hash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return reminderOn(db, id);
    }
    final invoice = await SupplierService.invoiceOn(db, id),
        old = await reminderOn(db, id);
    if (invoice.status != 'posted' ||
        invoice.due == null ||
        old.revision != expectedRevision) {
      throw const AppError('m53VisitChanged');
    }
    await db.insert('supplier_invoice_reminder_events', {
      'id': SupplierService._ids.next().value,
      'invoice_id': id.value,
      'revision': expectedRevision + 1,
      'enabled': enabled ? 1 : 0,
      'operation_key': operationKey,
      'payload_hash': hash,
      'actor_role': 'owner',
      'created_at': access.clock.milliseconds,
    });
    await access.audit(db, 'supplier_due_reminder_changed', entityId: id.value);
    return reminderOn(db, id);
  }, owner: true);
}
