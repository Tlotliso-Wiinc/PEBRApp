import 'dart:async';
import 'package:pebrapp/database/models/Patient.dart';
import 'package:pebrapp/database/models/PreferenceAssessment.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Access to the SQFLite database.
/// Get an instance either via `DatabaseProvider.instance` or via the singleton constructor `DatabaseProvider()`.
class DatabaseProvider {
  // Increase the _DB_VERSION number if you made changes to the database schema.
  // An increase will call the [_onUpgrade] method.
  static const int _DB_VERSION = 2;
  static Database _database;

  // private constructor for Singleton pattern
  DatabaseProvider._();

  static final DatabaseProvider instance = DatabaseProvider._();

  factory DatabaseProvider() {
    return instance;
  }

  get _databaseInstance async {
    if (_database != null) return _database;
    // if _database is null we instantiate it
    _database = await _initDB();
    return _database;
  }

  _initDB() async {
    String path = join(await getDatabasesPath(), "PEBRApp.db");
    print('DATABASE PATH: $path');
    return await openDatabase(path, version: _DB_VERSION, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    print('Creating database with version $version');
    await db.execute("""
        CREATE TABLE ${Patient.tableName} (
          ${Patient.colId} INTEGER PRIMARY KEY,
          ${Patient.colARTNumber} TEXT NOT NULL,
          ${Patient.colCreatedDate} INTEGER NOT NULL,
          ${Patient.colIsActivated} BIT NOT NULL,
          ${Patient.colIsVLSuppressed} BIT,
          ${Patient.colVillage} TEXT,
          ${Patient.colDistrict} TEXT,
          ${Patient.colPhoneNumber} TEXT,
          ${Patient.colLatestPreferenceAssessment} INTEGER
        );
        """);
    await db.execute("""
        CREATE TABLE ${PreferenceAssessment.tableName} (
          ${PreferenceAssessment.colId} INTEGER PRIMARY KEY,
          ${PreferenceAssessment.colPatientART} TEXT NOT NULL, 
          ${PreferenceAssessment.colCreatedDate} INTEGER NOT NULL,
          ${PreferenceAssessment.colARTRefillOption1} INTEGER NOT NULL,
          ${PreferenceAssessment.colARTRefillOption2} INTEGER,
          ${PreferenceAssessment.colARTRefillOption3} INTEGER,
          ${PreferenceAssessment.colARTRefillOption4} INTEGER,
          ${PreferenceAssessment.colARTRefillPersonName} TEXT,
          ${PreferenceAssessment.colARTRefillPersonPhoneNumber} TEXT,
          ${PreferenceAssessment.colPhoneAvailable} BIT NOT NULL,
          ${PreferenceAssessment.colPatientPhoneNumber} TEXT,
          ${PreferenceAssessment.colAdherenceReminderEnabled} BIT,
          ${PreferenceAssessment.colAdherenceReminderFrequency} INTEGER,
          ${PreferenceAssessment.colAdherenceReminderTime} TEXT,
          ${PreferenceAssessment.colAdherenceReminderMessage} TEXT,
          ${PreferenceAssessment.colVLNotificationEnabled} BIT,
          ${PreferenceAssessment.colVLNotificationMessageSuppressed} TEXT,
          ${PreferenceAssessment.colVLNotificationMessageUnsuppressed} TEXT,
          ${PreferenceAssessment.colPEPhoneNumber} TEXT,
          ${PreferenceAssessment.colSupportPreferences} TEXT
        );
        """);
        // TODO: set colLatestPreferenceAssessment as foreign key to `PreferenceAssessment` table
        //       set colPatientART as foreign key to `Patient` table
  }

  
  // Private Methods
  // ---------------

  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {

    print('Upgrading database from version $oldVersion to version $newVersion');
    if (oldVersion < 2) {
      print('Upgrading to database version 2...');

      // helper method
      _convertDatesFromIntToString(String tablename) async {
        List<Map<String, dynamic>> rows = await db.query(tablename, columns: ['id', 'created_date']);
        Batch batch = db.batch();
        for (Map<String, dynamic> row in rows) {
          int id = row['id'];
          int createdDateInMilliseconds = row['created_date'];
          String createdDateAsUTCString = DateTime.fromMillisecondsSinceEpoch(createdDateInMilliseconds).toUtc().toIso8601String();
          batch.update(
            tablename,
            {'created_date_utc': createdDateAsUTCString},
            where: 'id == ?',
            whereArgs: [id],
          );
          await batch.commit(noResult: true);
        }
      }

      // 1 - add new column 'created_date_utc'
      Batch batch = db.batch();
      batch.execute("ALTER TABLE Patient RENAME TO Patient_tmp;");
      batch.execute("ALTER TABLE Patient_tmp ADD created_date_utc TEXT NOT NULL DEFAULT '';");
      batch.execute("ALTER TABLE PreferenceAssessment RENAME TO PreferenceAssessment_tmp;");
      batch.execute("ALTER TABLE PreferenceAssessment_tmp ADD created_date_utc TEXT NOT NULL DEFAULT '';");
      await batch.commit(noResult: true);

      // 2 - change date representation to UTC String and store it in the new column
      await _convertDatesFromIntToString('Patient_tmp');
      await _convertDatesFromIntToString('PreferenceAssessment_tmp');

      // 3 - copy values from Patient_tmp to Patient
      // and from PreferenceAssessment_tmp to PreferenceAssessment
      batch = db.batch();
      batch.execute("""
        CREATE TABLE Patient (
          id INTEGER PRIMARY KEY,
          art_number TEXT NOT NULL,
          created_date_utc TEXT NOT NULL,
          is_activated BIT NOT NULL,
          is_vl_suppressed BIT,
          village TEXT,
          district TEXT,
          phone_number TEXT,
          latest_preference_assessment INTEGER
        );
      """);
      batch.execute("""
        INSERT INTO Patient
        SELECT id, art_number, created_date_utc, is_activated, is_vl_suppressed,
          village, district, phone_number, latest_preference_assessment
        FROM Patient_tmp;
      """);
      batch.execute("DROP TABLE Patient_tmp;");

      batch.execute("""
        CREATE TABLE PreferenceAssessment (
          id INTEGER PRIMARY KEY,
          patient_art TEXT NOT NULL, 
          created_date_utc TEXT NOT NULL,
          art_refill_option_1 INTEGER NOT NULL,
          art_refill_option_2 INTEGER,
          art_refill_option_3 INTEGER,
          art_refill_option_4 INTEGER,
          art_refill_person_name TEXT,
          art_refill_person_phone_number TEXT,
          phone_available BIT NOT NULL,
          patient_phone_number TEXT,
          adherence_reminder_enabled BIT,
          adherence_reminder_frequency INTEGER,
          adherence_reminder_time TEXT,
          adherence_reminder_message TEXT,
          vl_notification_enabled BIT,
          vl_notification_message_suppressed TEXT,
          vl_notification_message_unsuppressed TEXT,
          pe_phone_number TEXT,
          support_preferences TEXT
        );
      """);
      batch.execute("""
        INSERT INTO PreferenceAssessment
        SELECT id, patient_art, created_date_utc, art_refill_option_1,
          art_refill_option_2, art_refill_option_3, art_refill_option_4,
          art_refill_person_name, art_refill_person_phone_number,
          phone_available, patient_phone_number, adherence_reminder_enabled,
          adherence_reminder_frequency, adherence_reminder_time,
          adherence_reminder_message, vl_notification_enabled,
          vl_notification_message_suppressed,
          vl_notification_message_unsuppressed, pe_phone_number,
          support_preferences
        FROM PreferenceAssessment_tmp;
      """);
      batch.execute("DROP TABLE PreferenceAssessment_tmp;");

      await batch.commit(noResult: true);
    }
  }


  // Public Methods
  // --------------

  Future<void> insertPatient(Patient newPatient) async {
    final Database db = await _databaseInstance;
    newPatient.createdDate = DateTime.now().toUtc();
    final res = await db.insert(Patient.tableName, newPatient.toMap());
    return res;
  }

  /// Retrieves a list of all patient ART numbers in the database.
  Future<List<String>> retrievePatientsART() async {
    final Database db = await _databaseInstance;
    final res = await db.rawQuery("SELECT DISTINCT ${Patient.colARTNumber} FROM ${Patient.tableName}");
    return res.isNotEmpty ? res.map((entry) => entry[Patient.colARTNumber] as String).toList() : List<String>();
  }

  /// Retrieves only the latest patients from the database, i.e. the ones with the latest changes.
  ///
  /// SQL Query:
  /// SELECT Patient.* FROM Patient INNER JOIN (
  ///	  SELECT id, MAX(created_date) FROM Patient GROUP BY art_number
  ///	) latest ON Patient.id == latest.id
  Future<List<Patient>> retrieveLatestPatients() async {
    final Database db = await _databaseInstance;
    final res = await db.rawQuery("""
    SELECT ${Patient.tableName}.* FROM ${Patient.tableName} INNER JOIN (
	    SELECT ${Patient.colId}, MAX(${Patient.colCreatedDate}) FROM ${Patient.tableName} GROUP BY ${Patient.colARTNumber}
	  ) latest ON ${Patient.tableName}.${Patient.colId} == latest.${Patient.colId}
    """);
    List<Patient> list = List<Patient>();
    if (res.isNotEmpty) {
      for (Map<String, dynamic> map in res) {
        Patient p = Patient.fromMap(map);
        await p.initializePreferenceAssessmentField();
        list.add(p);
      }
    }
    return list;
  }

  Future<void> insertPreferenceAssessment(PreferenceAssessment newPreferenceAssessment) async {
    final Database db = await _databaseInstance;
    newPreferenceAssessment.createdDate = DateTime.now().toUtc();
    final res = await db.insert(PreferenceAssessment.tableName, newPreferenceAssessment.toMap());
    return res;
  }

  Future<PreferenceAssessment> retrieveLatestPreferenceAssessmentForPatient(String patientART) async {
    final Database db = await _databaseInstance;
    final List<Map> res = await db.query(
        PreferenceAssessment.tableName,
        where: '${PreferenceAssessment.colPatientART} = ?',
        whereArgs: [patientART],
        orderBy: PreferenceAssessment.colCreatedDate
    );
    if (res.length > 0) {
      return PreferenceAssessment.fromMap(res.first);
    }
    return null;
  }


  // Debug methods (should be removed/disabled for final release)
  // ------------------------------------------------------------
  // TODO: remove/disable these functions for the final release

  /// Retrieves all patients from the database, including duplicates created when editing a patient.
  Future<List<Patient>> retrieveAllPatients() async {
    final Database db = await _databaseInstance;
    // query the table for all patients
    final res = await db.query(Patient.tableName);
    List<Patient> list = List<Patient>();
    if (res.isNotEmpty) {
      for (Map<String, dynamic> map in res) {
        Patient p = Patient.fromMap(map);
        await p.initializePreferenceAssessmentField();
        list.add(p);
      }
    }
    return list;
  }

  /// Retrieves a table's column names.
  Future<List<Map<String, dynamic>>> getTableInfo(String tableName) async {
    final Database db = await _databaseInstance;
    var res = db.rawQuery("PRAGMA table_info($tableName);");
    return res;
  }

  /// Deletes a patient from the Patient table and its corresponding entries from the PreferenceAssessment table.
  Future<int> deletePatient(Patient deletePatient) async {
    final Database db = await _databaseInstance;
    final String artNumber = deletePatient.artNumber;
    final int rowsDeletedPatientTable = await db.delete(Patient.tableName, where: '${Patient.colARTNumber} = ?', whereArgs: [artNumber]);
    final int rowsDeletedPreferenceAssessmentTable = await db.delete(PreferenceAssessment.tableName, where: '${PreferenceAssessment.colPatientART} = ?', whereArgs: [artNumber]);
    return rowsDeletedPatientTable + rowsDeletedPreferenceAssessmentTable;
  }

}
