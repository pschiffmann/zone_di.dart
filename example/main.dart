/// Example of how a server side framework might use this package to pass
/// configuration and dependencies around via dependency injection.
///
/// Class names borrowed from [Aqueduct](https://aqueduct.io).
library zone_di.example;

import 'package:zone_di2/zone_di2.dart';

//
// Persistence layer interface
//

final persistentStoreToken =
    Token<PersistentStore>('zone_di.example.persistentStoreToken');

abstract class PersistentStore {}

//
// Postgres implementation of persistence layer
//

final databaseCredentialsToken =
    Token<DatabaseConfiguration>('zone_di.example.databaseCredentialsToken');

class DatabaseConfiguration {
  DatabaseConfiguration(this.username, this.password);
  final String username;
  final String password;
}

class PostgreSQLPersistentStore implements PersistentStore {
  PostgreSQLPersistentStore() {
    final credentials = inject(databaseCredentialsToken);
    connect(credentials.username, credentials.password);
  }

  void connect(String username, String password) {/* ... */}
}

//
// Bootstrapping
//

class App {
  App() : persistentStore = inject(persistentStoreToken);

  final PersistentStore? persistentStore;

  void run() {/* ... */}
}

void main() {
  provideFactories({
    persistentStoreToken: () => PostgreSQLPersistentStore(),
    databaseCredentialsToken: () =>
        DatabaseConfiguration('pschiffmann', 'dolphins')
  }, () {
    final app = App();
    app.run();
  });
}
