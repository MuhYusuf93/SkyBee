/// Visit plans are operational, never receipts/payments. Mutable projections
/// require a matching append-only revision; reminder jobs are rebuildable cache.
final supplierScheduleSchema = <String>[
  '''CREATE TABLE supplier_visits(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    supplier_name TEXT NOT NULL CHECK(length(trim(supplier_name)) BETWEEN 1 AND 200),
    visit_date TEXT NOT NULL CHECK(length(visit_date)=10),
    time_minutes INTEGER CHECK(time_minutes IS NULL OR (typeof(time_minutes)='integer' AND time_minutes BETWEEN 0 AND 1439)),
    note TEXT CHECK(note IS NULL OR length(note)<=1000),
    status TEXT NOT NULL CHECK(status IN ('planned','completed','cancelled')),
    reminder INTEGER NOT NULL CHECK(reminder IN (0,1)),
    revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>=1),
    created_at INTEGER NOT NULL CHECK(created_at>=0),
    updated_at INTEGER NOT NULL CHECK(updated_at>=0))''',
  '''CREATE TABLE supplier_visit_events(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    visit_id TEXT NOT NULL REFERENCES supplier_visits(id) ON DELETE RESTRICT,
    revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>=1),
    supplier_name TEXT NOT NULL CHECK(length(trim(supplier_name)) BETWEEN 1 AND 200),
    visit_date TEXT NOT NULL CHECK(length(visit_date)=10),
    time_minutes INTEGER CHECK(time_minutes IS NULL OR (typeof(time_minutes)='integer' AND time_minutes BETWEEN 0 AND 1439)),
    note TEXT CHECK(note IS NULL OR length(note)<=1000),
    status TEXT NOT NULL CHECK(status IN ('planned','completed','cancelled')),
    reminder INTEGER NOT NULL CHECK(reminder IN (0,1)),
    operation_key TEXT NOT NULL UNIQUE CHECK(length(operation_key) BETWEEN 1 AND 200),
    payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    actor_role TEXT NOT NULL CHECK(actor_role IN ('owner','warehouse')),
    created_at INTEGER NOT NULL CHECK(created_at>=0),UNIQUE(visit_id,revision))''',
  '''CREATE TABLE supplier_invoice_reminder_events(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    invoice_id TEXT NOT NULL REFERENCES supplier_invoices(id) ON DELETE RESTRICT,
    revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>=1),
    enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
    operation_key TEXT NOT NULL UNIQUE CHECK(length(operation_key) BETWEEN 1 AND 200),
    payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    actor_role TEXT NOT NULL CHECK(actor_role='owner'),
    created_at INTEGER NOT NULL CHECK(created_at>=0),UNIQUE(invoice_id,revision))''',
  '''CREATE TRIGGER supplier_visits_update BEFORE UPDATE ON supplier_visits WHEN
    NEW.id<>OLD.id OR NEW.supplier_id<>OLD.supplier_id OR NEW.created_at<>OLD.created_at OR NEW.revision<>OLD.revision+1 OR
    NOT EXISTS(SELECT 1 FROM supplier_visit_events e WHERE e.visit_id=OLD.id AND e.revision=NEW.revision AND
      e.supplier_name=NEW.supplier_name AND e.visit_date=NEW.visit_date AND e.time_minutes IS NEW.time_minutes AND
      e.note IS NEW.note AND e.status=NEW.status AND e.reminder=NEW.reminder AND e.created_at=NEW.updated_at)
    BEGIN SELECT RAISE(ABORT,'supplier_visit_revision_required'); END''',
  "CREATE TRIGGER supplier_visits_no_delete BEFORE DELETE ON supplier_visits BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
  for (final table in [
    'supplier_visit_events',
    'supplier_invoice_reminder_events',
  ]) ...[
    "CREATE TRIGGER ${table}_no_update BEFORE UPDATE ON $table BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
    "CREATE TRIGGER ${table}_no_delete BEFORE DELETE ON $table BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
  ],
  'CREATE INDEX supplier_visits_next ON supplier_visits(supplier_id,status,visit_date,id COLLATE BINARY)',
  'CREATE INDEX supplier_visits_calendar ON supplier_visits(status,visit_date,id COLLATE BINARY)',
  '''CREATE TABLE supplier_reminder_runtime(id INTEGER PRIMARY KEY CHECK(id=1),generation INTEGER NOT NULL DEFAULT 0 CHECK(generation>=0))''',
  'INSERT INTO supplier_reminder_runtime(id) VALUES(1)',
  '''CREATE TABLE supplier_reminder_jobs(
    object_key TEXT PRIMARY KEY NOT NULL,
    store_id TEXT NOT NULL,kind TEXT NOT NULL CHECK(kind IN ('visit','due')),
    source_id TEXT NOT NULL CHECK(length(source_id)=36),
    supplier_name TEXT NOT NULL,target_ms INTEGER NOT NULL,
    reminder_day TEXT NOT NULL,event_day TEXT NOT NULL,zone TEXT NOT NULL,
    fingerprint TEXT NOT NULL,work_name TEXT NOT NULL,
    notification_id INTEGER NOT NULL UNIQUE CHECK(notification_id BETWEEN 1000000000 AND 1499999999),
    seen_generation INTEGER NOT NULL,active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
    scheduled_fingerprint TEXT,delivered_target INTEGER,error_code TEXT)''',
  'CREATE INDEX supplier_reminder_jobs_seen ON supplier_reminder_jobs(seen_generation,object_key COLLATE BINARY)',
];
