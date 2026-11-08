part of 'inventory_service.dart';

/// Receipt pages share the draft revision and private SQLCipher transaction.
/// Warehouse can edit an open draft. Posted photos require owner access.
extension ReceiptPhotos on InventoryService {
  Future<({int revision, bool editable})> _photoAccessOn(
    DatabaseExecutor db,
    EntityId draft,
  ) async {
    final rows = await db.query(
      'receipt_drafts',
      columns: ['revision', 'status'],
      where: 'id=?',
      whereArgs: [draft.value],
    );
    if (rows.isEmpty || rows.single['status'] == 'cancelled') {
      throw const AppError('m53ReceiptDraftChanged');
    }
    final editable = rows.single['status'] == 'draft';
    await access.authorize(
      db,
      capability: editable
          ? ManagementCapability.inventory
          : ManagementCapability.owner,
    );
    return (revision: rows.single['revision'] as int, editable: editable);
  }

  Future<({int revision, bool editable, List<ReceiptPhotoPage> pages})>
  receiptPhotoPages(EntityId draft) => _read((db) async {
    final permit = await _photoAccessOn(db, draft);
    final rows = await db.rawQuery(
      '''SELECT id,position,width,height,quarter_turns,length(jpeg) AS byte_length
      FROM receipt_photos WHERE draft_id=? ORDER BY position,id COLLATE BINARY LIMIT 9''',
      [draft.value],
    );
    if (rows.length > ReceiptPhotoAsset.maxPages) {
      throw ReceiptPhotoAsset.invalid;
    }
    await _photoAccessOn(db, draft);
    return (
      revision: permit.revision,
      editable: permit.editable,
      pages: List<ReceiptPhotoPage>.unmodifiable(
        rows.map(ReceiptPhotoPage.new),
      ),
    );
  });

  Future<ReceiptPhotoAsset> receiptPhoto(EntityId draft, EntityId page) =>
      _read((db) async {
        await _photoAccessOn(db, draft);
        final rows = await db.query(
          'receipt_photos',
          columns: ['jpeg', 'sha256', 'width', 'height'],
          where: 'id=? AND draft_id=? AND length(jpeg)<=?',
          whereArgs: [page.value, draft.value, ReceiptPhotoAsset.maxBytes],
        );
        if (rows.isEmpty) throw ReceiptPhotoAsset.invalid;
        final row = rows.single;
        final photo = ReceiptPhotoAsset.fromJpeg(row['jpeg'] as Uint8List);
        if (photo.hash != row['sha256'] ||
            photo.width != row['width'] ||
            photo.height != row['height']) {
          throw ReceiptPhotoAsset.invalid;
        }
        await _photoAccessOn(db, draft);
        return photo;
      });

  Future<void> saveReceiptPhoto(
    EntityId draft,
    int revision,
    ReceiptPhotoAsset image, {
    EntityId? replace,
    void Function()? requireIntent,
  }) => _draftWrite((db) async {
    final doc = await _editableReceiptOn(db, draft, revision);
    final values = {
      'jpeg': image.jpeg,
      'sha256': image.hash,
      'width': image.width,
      'height': image.height,
      'quarter_turns': 0,
      'created_at': access.clock.milliseconds,
    };
    final page = replace ?? InventoryService._ids.next();
    if (replace != null) {
      if (await db.update(
            'receipt_photos',
            values,
            where: 'id=? AND draft_id=?',
            whereArgs: [page.value, draft.value],
          ) !=
          1) {
        throw const AppError('m53ReceiptDraftChanged');
      }
    } else {
      final counts = (await db.rawQuery(
        'SELECT COUNT(*) AS pages,MAX(position) AS last FROM receipt_photos WHERE draft_id=?',
        [draft.value],
      )).single;
      if ((counts['pages'] as int) >= ReceiptPhotoAsset.maxPages) {
        throw const AppError('m54ReceiptPhotoLimit');
      }
      await db.insert('receipt_photos', {
        ...values,
        'id': page.value,
        'draft_id': draft.value,
        'position': ((counts['last'] as int?) ?? -1) + 1,
      });
    }
    await _bumpReceiptOn(db, doc);
    await access.audit(db, 'receipt_photo_saved', entityId: page.value);
  }, requireIntent: requireIntent);

  Future<void> rotateReceiptPhoto(
    EntityId draft,
    int revision,
    EntityId page, {
    void Function()? requireIntent,
  }) => _draftWrite((db) async {
    final doc = await _editableReceiptOn(db, draft, revision);
    if (await db.rawUpdate(
          'UPDATE receipt_photos SET quarter_turns=(quarter_turns+1)%4 WHERE id=? AND draft_id=?',
          [page.value, draft.value],
        ) !=
        1) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    await _bumpReceiptOn(db, doc);
  }, requireIntent: requireIntent);

  Future<void> removeReceiptPhoto(
    EntityId draft,
    int revision,
    EntityId page, {
    void Function()? requireIntent,
  }) => _draftWrite((db) async {
    final doc = await _editableReceiptOn(db, draft, revision);
    if (await db.delete(
          'receipt_photos',
          where: 'id=? AND draft_id=?',
          whereArgs: [page.value, draft.value],
        ) !=
        1) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    await _bumpReceiptOn(db, doc);
    await access.audit(db, 'receipt_photo_removed', entityId: page.value);
  }, requireIntent: requireIntent);
}
