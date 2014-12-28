MySQL adapter for DartORM.
===============================

It uses sqljocky package to interact with mysql database and provides api
for DartORM.

https://github.com/ustims/DartORM

Better example can be found in DartORM integration tests package:

https://github.com/ustims/DartORM/blob/master/test/integration/integration_tests.dart


Usage example
-------------

```dart
import 'package:dart_orm/dart_orm.dart' as ORM;
import 'package:dart_orm_adapter_mysql/dart_orm_adapter_mysql.dart';

...

MySQLDBAdapter mysqlAdapter = new MySQLDBAdapter(
    'mysql://dart_orm_test:dart_orm_test@localhost:3306/dart_orm_test'
  );
await mysqlAdapter.connect();
ORM.Model.ormAdapter = mysqlAdapter;
migrationResult = await ORM.Migrator.migrate();
assert(migrationResult);
```