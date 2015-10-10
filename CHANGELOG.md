## 0.1.2

- Added close() method.
- sqljocky version constraint raised to ^0.12.0 which supports ConnectionPool.closeConnectionsWhenNotInUse

## 0.1.1

- Support the latest release of `dart_orm`

## 0.1.0

- Added a new constructor `MySQLDBAdapter.withDetails`.
- Arguments to `new MySQLDBAdapter` are validated immediately.
- Allow `connectionString` to be a `Uri` instance.

## 0.0.9+2

- Fix async for loop bug in `MySQLDBAdapter.select`.

## 0.0.9+1

- Fix a bug in `MySQLDBAdapter.connect`.

## 0.0.9

- Require at least Dart 1.9

- Allow recent releases of `sqljocky`

## 0.0.8

- Milliseconds rounding for MySQL < 5.6.4.

## 0.0.6

- getting mysql version added with
  pub_semver package usage for supported features checks.

## 0.0.5

- Much better logging.

## 0.0.4

- DateTime milliseconds removed because it is only supported by new versions.

## 0.0.3

- DateTime support added.

## 0.0.1

- Initial release.
