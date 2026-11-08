/// Member browsing uses creation time as recorded, including legacy profiles.
const memberHistorySchema = [
  'CREATE INDEX members_created ON customers(is_deleted,created_at,id COLLATE BINARY)',
];
