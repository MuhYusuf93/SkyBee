/// One replaceable, encrypted-store asset. The selected source file is never
/// referenced by checkout, backup, or the app's process after import.
const qrisAssetSchema = [
  '''CREATE TABLE store_qris_asset(
    id INTEGER PRIMARY KEY CHECK(id=1),
    hash TEXT NOT NULL CHECK(length(hash)=64),
    bytes BLOB NOT NULL CHECK(typeof(bytes)='blob' AND length(bytes) BETWEEN 1 AND 4194304),
    width INTEGER NOT NULL CHECK(typeof(width)='integer' AND width BETWEEN 64 AND 4096),
    height INTEGER NOT NULL CHECK(typeof(height)='integer' AND height BETWEEN 64 AND 4096),
    CHECK(width*height<=4194304))''',
];
