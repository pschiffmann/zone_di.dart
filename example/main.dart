/// Example of how a server side framework might use this package to pass
/// configuration and dependencies around via dependency injection.
///
/// Class names borrowed from [Aqueduct](https://aqueduct.io).
library scope.example;

import 'package:di_zone2/di_zone2.dart';

//
// Persistence layer interface
//

final persistentStoreScopeKey =
    ScopeKey<PersistentStore>('zone_di.example.persistentStoreScopeKey');

abstract class PersistentStore {}

//
// Postgres implementation of persistence layer
//

final databaseCredentialsScopeKey = ScopeKey<DatabaseConfiguration>(
    'zone_di.example.databaseCredentialsScopeKey');

class DatabaseConfiguration {
  DatabaseConfiguration(this.username, this.password);
  final String username;
  final String password;
}

class PostgreSQLPersistentStore implements PersistentStore {
  PostgreSQLPersistentStore() {
    final credentials = use(databaseCredentialsScopeKey);
    connect(credentials.username, credentials.password);
  }

  void connect(String username, String password) {/* ... */}
}

//
// Bootstrapping
//

class App {
  App() : persistentStore = use(persistentStoreScopeKey);

  final PersistentStore? persistentStore;

  void run() {/* ... */}
}

// void main() {
//   provideFactories({
//     persistentStoreScopeKey: () => PostgreSQLPersistentStore(),
//     databaseCredentialsScopeKey: () =>
//         DatabaseConfiguration('pschiffmann', 'dolphins')
//   }, () {
//     App().run();
//   });
// }
