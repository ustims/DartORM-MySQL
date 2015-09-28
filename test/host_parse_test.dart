import 'package:test/test.dart';
import 'package:dart_orm_adapter_mysql/dart_orm_adapter_mysql.dart';

void main() {
  test('simple', () {
    var adapter = new MySQLDBAdapter('mysql://example.com');

    expect(adapter.host, 'example.com');
    expect(adapter.port, 3306, reason: 'the default');

    expect(adapter.userName, '');
    expect(adapter.password, '');
    expect(adapter.databaseName, '');
  });

  test('complex', () {
    var adapter =
        new MySQLDBAdapter('mysql://user:password@example.com:1234/dbname');

    expect(adapter.host, 'example.com');
    expect(adapter.port, 1234);

    expect(adapter.userName, 'user');
    expect(adapter.password, 'password');
    expect(adapter.databaseName, 'dbname');
  });
}
