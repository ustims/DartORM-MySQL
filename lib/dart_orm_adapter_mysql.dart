library dart_orm_adapter_mysql;

import 'package:dart_orm/dart_orm.dart';
import 'package:sqljocky/sqljocky.dart' as mysql_connector;
import 'dart:async';


class MySQLDBAdapter extends SQLAdapter with DBAdapter {
  String _connectionString;

  MySQLDBAdapter(String connectionString) {
    _connectionString = connectionString;
  }

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
      uri.port = 3306;
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

    this.connection = new mysql_connector.ConnectionPool(
        host: uri.host,
        port: uri.port,
        user: userName,
        password: password,
        db: databaseName, max: 5);

    await this.connection.query('show tables');
  }

  Future createTable(Table table) async {
    String sqlQueryString = SQLAdapter.constructTableSql(table);
    var prepared = await connection.prepare(sqlQueryString);
    var result = null;

    result = await prepared.execute();
    return result;
  }

  Future<List<Map>> select(Select select) {
    Completer completer = new Completer();

    String sqlQueryString = SQLAdapter.constructSelectSql(select);
    List<Map> results = new List<Map>();

    this.connection.query(sqlQueryString)
    .then((rawResults) {
      return rawResults.forEach((rawRow) {
        Map<String, dynamic> row = new Map<String, dynamic>();

        int fieldNumber = 0;
        for (Field f in select.table.fields) {
          if (rawRow[fieldNumber] is mysql_connector.Blob) {
            row[f.fieldName] = rawRow[fieldNumber].toString();
          } else {
            row[f.fieldName] = rawRow[fieldNumber];
          }

          fieldNumber ++;
        }

        results.add(row);

      });
    })
    .then((r) {
      completer.complete(results);
    })
    .catchError((e) {
      if (e is mysql_connector.MySqlException) {
        switch (e.errorNumber) {
          case 1146:
            completer.completeError(new TableNotExistException());
            break;
          case 1072:
            completer.completeError(new ColumnNotExistException());
            break;
          default:
            completer.completeError(new UnknownAdapterException(e));
            break;
        }
      } else {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  Future<int> insert(Insert insert) async {
    String sqlQueryString = SQLAdapter.constructInsertSql(insert);

    var prepared = await connection.prepare(sqlQueryString);
    var result = await prepared.execute();

    if (result.insertId != null) {
      // if we have any results, here will be returned new primary key
      // of the inserted row
      return result.insertId;
    }

    // if model doesn't have primary key we simply return 0
    return 0;
  }

  Future<int> update(Update update) async {
    String sqlQueryString = SQLAdapter.constructUpdateSql(update);

    var prepared = await connection.prepare(sqlQueryString);
    var result = await prepared.execute();

    return result.affectedRows;
  }
}