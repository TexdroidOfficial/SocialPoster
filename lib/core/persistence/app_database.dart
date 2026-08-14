import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open() async {
    final directory = await getApplicationSupportDirectory();
    final database = sqlite3.open(
      p.join(directory.path, 'social_poster.sqlite'),
    );
    final appDatabase = AppDatabase._(database);
    appDatabase._migrate();
    return appDatabase;
  }

  static AppDatabase inMemory() {
    final database = AppDatabase._(sqlite3.openInMemory());
    database._migrate();
    return database;
  }

  void _migrate() {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)
    ''');
    final rows = _db.select('SELECT version FROM schema_version LIMIT 1');
    if (rows.isEmpty) _db.execute('INSERT INTO schema_version VALUES (1)');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY, provider TEXT NOT NULL, provider_account_id TEXT NOT NULL,
        label TEXT NOT NULL, secret_ref TEXT NOT NULL, capabilities TEXT NOT NULL,
        status TEXT NOT NULL, last_validated_at TEXT
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS assets (
        id TEXT PRIMARY KEY, path TEXT NOT NULL, kind TEXT NOT NULL, mime TEXT NOT NULL,
        bytes INTEGER NOT NULL, modified_at TEXT NOT NULL, content_hash TEXT,
        public_url TEXT, retention TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS jobs (
        id TEXT PRIMARY KEY, caption TEXT NOT NULL, created_at TEXT NOT NULL, state TEXT NOT NULL,
        intent_json TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS destination_tasks (
        id TEXT PRIMARY KEY, job_id TEXT NOT NULL, provider TEXT NOT NULL, account_id TEXT NOT NULL,
        state TEXT NOT NULL, phase TEXT NOT NULL, progress REAL NOT NULL, attempts INTEGER NOT NULL,
        provider_operation_id TEXT, error_kind TEXT, error_message TEXT,
        FOREIGN KEY(job_id) REFERENCES jobs(id) ON DELETE CASCADE
      )
    ''');
  }

  void insertAccount({required Map<String, Object?> values}) {
    _db.execute('''INSERT OR REPLACE INTO accounts
      (id, provider, provider_account_id, label, secret_ref, capabilities, status, last_validated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)''', values.values.toList());
  }

  List<Map<String, Object?>> accounts() =>
      _db.select('SELECT * FROM accounts ORDER BY label').map(_row).toList();

  void insertJob({required Map<String, Object?> values}) {
    _db.execute(
      'INSERT OR REPLACE INTO jobs (id, caption, created_at, state, intent_json) VALUES (?, ?, ?, ?, ?)',
      values.values.toList(),
    );
  }

  List<Map<String, Object?>> jobs() => _db
      .select('SELECT * FROM jobs ORDER BY created_at DESC')
      .map(_row)
      .toList();

  void insertDestination({required Map<String, Object?> values}) {
    _db.execute('''INSERT OR REPLACE INTO destination_tasks
      (id, job_id, provider, account_id, state, phase, progress, attempts, provider_operation_id, error_kind, error_message)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''', values.values.toList());
  }

  List<Map<String, Object?>> destinations(String jobId) => _db
      .select('SELECT * FROM destination_tasks WHERE job_id = ?', [jobId])
      .map(_row)
      .toList();

  Map<String, Object?> _row(Row row) => {
    for (final column in row.keys) column: row[column],
  };

  void close() => _db.dispose();
}
