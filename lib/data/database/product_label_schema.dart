/// Label preferences survive absent peripheral bindings on portable restore.
/// They can only be applied after an explicit current printer/profile check.
const productLabelSchema = <String>[
  '''CREATE TABLE product_label_profiles(
    device_id TEXT PRIMARY KEY NOT NULL CHECK(length(device_id) BETWEEN 1 AND 256),
    revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>=1),
    settings_json TEXT NOT NULL CHECK(length(settings_json) BETWEEN 2 AND 4096),
    updated_at INTEGER NOT NULL CHECK(typeof(updated_at)='integer' AND updated_at>=0))''',
];
