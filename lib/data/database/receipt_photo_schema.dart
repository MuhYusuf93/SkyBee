/// Photos live inside the encrypted database alongside their draft and receipt
/// witness. An atomic transaction replaces a page without a filesystem orphan.
const receiptPhotoSchema = [
  '''CREATE TABLE receipt_photos(
    id TEXT NOT NULL PRIMARY KEY CHECK(length(id)=36),
    draft_id TEXT NOT NULL REFERENCES receipt_drafts(id) ON DELETE RESTRICT,
    position INTEGER NOT NULL CHECK(position>=0),
    jpeg BLOB NOT NULL CHECK(typeof(jpeg)='blob' AND length(jpeg) BETWEEN 16 AND 786432),
    sha256 TEXT NOT NULL CHECK(length(sha256)=64),
    width INTEGER NOT NULL CHECK(width BETWEEN 64 AND 1280),
    height INTEGER NOT NULL CHECK(height BETWEEN 64 AND 2560),
    quarter_turns INTEGER NOT NULL DEFAULT 0 CHECK(quarter_turns BETWEEN 0 AND 3),
    created_at INTEGER NOT NULL CHECK(created_at>=0),
    UNIQUE(draft_id,position))''',
  '''CREATE TRIGGER receipt_photo_insert BEFORE INSERT ON receipt_photos
    WHEN (SELECT status FROM receipt_drafts WHERE id=NEW.draft_id) IS NOT 'draft'
      OR (SELECT COUNT(*) FROM receipt_photos WHERE draft_id=NEW.draft_id)>=8
    BEGIN SELECT RAISE(ABORT,'invalid_receipt_photo'); END''',
  '''CREATE TRIGGER receipt_photo_update BEFORE UPDATE ON receipt_photos
    WHEN NEW.id<>OLD.id OR NEW.draft_id<>OLD.draft_id OR NEW.position<>OLD.position
      OR (SELECT status FROM receipt_drafts WHERE id=OLD.draft_id) IS NOT 'draft'
    BEGIN SELECT RAISE(ABORT,'immutable_receipt_photo'); END''',
  '''CREATE TRIGGER receipt_photo_delete BEFORE DELETE ON receipt_photos
    WHEN (SELECT status FROM receipt_drafts WHERE id=OLD.draft_id) IS NOT 'draft'
    BEGIN SELECT RAISE(ABORT,'immutable_receipt_photo'); END''',
];
