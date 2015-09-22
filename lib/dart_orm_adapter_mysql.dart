library dart_orm_adapter_mysql;

import 'package:dart_orm/dart_orm.dart';

import 'dart:async';
import 'dart:collection';

import 'package:sqljocky/sqljocky.dart' as mysql_connector;
import 'package:logging/logging.dart';
import 'package:pub_semver/pub_semver.dart';

class MySQLDBAdapter extends SQLAdapter with DBAdapter {
  final String _connectionString;
  final Logger log = new Logger('DartORM.MySQLDBAdapter');

  mysql_connector.ConnectionPool get connection => super.connection;

  LinkedHashMap<String, String> _connectionDBInfo = new LinkedHashMap();
  Version _mysqlVersion = null;

  /**
   * MySQL support fractional seconds(milliseconds) only from this version.
   * http://dev.mysql.com/doc/refman/5.6/en/fractional-seconds.html
   */
  static final VersionConstraint FEATURE_FRACTIONAL_SECONDS =
      new VersionConstraint.parse(">=5.6.4");

  /**
   * Checks whether currently connected database supports a feature.
   * Features version constraints defined above as FEATURE_* properties.
   */
  bool dbSupports(VersionConstraint feature) {
    if (feature.allows(_mysqlVersion)) {
      return true;
    } else {
      return false;
    }
  }

  MySQLDBAdapter(String connectionString)
      : this._connectionString = connectionString;

  Future connect() async {
    String userName = '';
    String password = '';
    String databaseName = '';

    var uri = Uri.parse(_connectionString);
    if (uri.scheme != 'mysql') {
      throw new Exception(
          'Invalid scheme in uri: $_connectionString ${uri.scheme}');
    }

    if (uri.port == null || uri.port == 0) {
      uri = uri.replace(port: 3306);
    }
    if (uri.userInfo != '') {
      var userInfo = uri.userInfo.split(':');
      if (userInfo.length != 2) {
        throw new Exception('Invalid format of userInfo field: $uri.userInfo');
      }
      userName = userInfo[0];
      password = userInfo[1];
    }
    if (uri.path != '') {
      databaseName = uri.path.replaceAll('/', '');
    }

    log.finest(
        'Connecting to ${userName}@${uri.host}:${uri.port}/${databaseName}');

    this.connection = new mysql_connector.ConnectionPool(
        host: uri.host,
        port: uri.port,
        user: userName,
        password: password,
        db: databaseName,
        max: 5);

    var versionInfo =
        await this.connection.query('SHOW VARIABLES LIKE "%version%";');

    await for (var vInfo in versionInfo) {
      if (vInfo[0] == 'version') {
        _mysqlVersion = new Version.parse(vInfo[1]);
        log.fine('MySQL version: ' + _mysqlVersion.toString());
        log.fine('Supported features:');
        log.fine(
            'FEATURE_FRACTIONAL_SECONDS: ${dbSupports(FEATURE_FRACTIONAL_SECONDS)}');
      }
      _connectionDBInfo[vInfo[0]] = vInfo[1];
    }
  }

  Future createTable(Table table) async {
    String sqlQueryString = this.constructTableSql(table);
    log.finest('Create table:');
    log.finest(sqlQueryString);
    var prepared = await connection.prepare(sqlQueryString);
    var result = null;

    result = await prepared.execute();
    log.finest('Result:');
    log.finest(result);
    return result;
  }

  Future<List<Map>> select(Select select) async {
    log.finest('Select:');

    String sqlQueryString = this.constructSelectSql(select);
    log.finest(sqlQueryString);


    try {
      var rawResults = await this.connection.query(sqlQueryString);

      List<Map> results = new List<Map>();
      await for (var rawRow in rawResults) {
        Map<String, dynamic> row = new Map<String, dynamic>();

        int fieldNumber = 0;
        for (Field f in select.table.fields) {
          var rawField = rawRow[fieldNumber];
          if (rawField is mysql_connector.Blob) {
            row[f.fieldName] = rawField.toString();
          } else {
            row[f.fieldName] = rawField;
          }

          fieldNumber++;
        }

        results.add(row);
      }

      log.finest('Result:');
      log.finest(results);

      return results;
    } on mysql_connector.MySqlException catch (e, stack) {
      log.severe('MySqlException', e, stack);
      switch (e.errorNumber) {
        case 1146:
          throw new TableNotExistException();
        case 1072:
          throw new ColumnNotExistException();
        default:
          throw new UnknownAdapterException(e);
      }
    } catch (e, stack) {
      log.severe('Exception', e, stack);
      rethrow;
    }
  }

  Future<int> insert(Insert insert) async {
    log.finest('Insert:');
    String sqlQueryString = this.constructInsertSql(insert);
    log.finest(sqlQueryString);

    var prepared = await connection.prepare(sqlQueryString);
    var result = await prepared.execute();

    log.finest(
        'Affected rows: ${result.affectedRows}, insertId: ${result.insertId}');

    if (result.insertId != null) {
      // if we have any results, here will be returned new primary key
      // of the inserted row
      return result.insertId;
    }

    // if model doesn't have primary key we simply return 0
    return 0;
  }

  Future<int> update(Update update) async {
    log.finest('Update:');
    String sqlQueryString = this.constructUpdateSql(update);
    log.finest(sqlQueryString);

    var prepared = await connection.prepare(sqlQueryString);
    var result = await prepared.execute();
    log.finest(result);

    return result.affectedRows;
  }

  /**
   * This method is invoked when db table(column) is created to determine
   * what sql type to use.
   */
  String getSqlType(Field field) {
    String dbTypeName = super.getSqlType(field);

    if (dbTypeName.length < 1) {
      switch (field.propertyTypeName) {
        case 'DateTime':
          if (dbSupports(FEATURE_FRACTIONAL_SECONDS)) {
            dbTypeName = 'DATETIME(3)';
          } else {
            dbTypeName = 'DATETIME';
          }

          break;
      }
    }

    return dbTypeName;
  }

  TypedSQL getTypedSqlFromValue(var instanceFieldValue, [Table table = null]) {
    TypedSQL value = super.getTypedSqlFromValue(instanceFieldValue, table);
    if (value is DateTimeSQL) {
      DateTime dt = value.value;
      if (!dbSupports(FEATURE_FRACTIONAL_SECONDS)) {
        DateTime withoutMillis = null;
        if (dt.millisecond > 500) {
          withoutMillis = new DateTime.fromMillisecondsSinceEpoch(
              dt.millisecondsSinceEpoch + (1000 - dt.millisecond));
        } else {
          withoutMillis = new DateTime.fromMillisecondsSinceEpoch(
              dt.millisecondsSinceEpoch - dt.millisecond);
        }
        value = new DateTimeSQL(withoutMillis);
      }
    }

    return value;
  }
}
