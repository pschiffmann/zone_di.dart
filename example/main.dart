/// Example of how you might use Scope to implement a Db Transaction
/// and inject depedencies such as the tenant into each query.
///
/// Class names borrowed from [simple_mysql_orm](https://pub.dev/packages/simple_mysql_orm).
library scope.example;

import 'package:money2/money2.dart';
import 'package:scope/scope.dart';


/// declare the keys we use to inject values.
final tenantKey = ScopeKey<int>();
final licenseType = ScopeKey<LicenseType>();
final licenseFee = ScopeKey<Money>();


void main() {
  /// Inject details required to bill a tenant.
  Scope()
    ..value(tenantKey, 1)
    ..value(licenseType, LicenseType.pro)
    ..single(licenseFee, getLicenseFee)
    ..run(() {
      Tenant().bill();
    });
}


class Tenant {
  Future<void> bill() async {
    await withTransaction<void>(() async {
      
      /// get the injected Db.
      Transaction.current.db
        ..query(
          'select * from tenant where tenant = ?',
          [use(tenantKey)],
        )
        ..query(
          'insert into billing (tenantId, date, amountInCents) values(?,?,?)',
          [use(tenantKey), DateTime.now(), use(licenseFee).minorUnits],
        );
    });
  }
}

/// Use Scope to create transactions scopes that
/// inject a Db connection.
Future<R?> withTransaction<R>(Future<R> Function() action) async {
  final db = DbPool().obtain();
  try {
    final transaction = Transaction<R>(db);

    return await (Scope()..value(Transaction.transactionKey, transaction))
        .run(() async => transaction.run(action));
  } finally {
    DbPool().release(db);
  }
}

class Transaction<R> {
  /// Create a database transaction for [db].
  ///
  Transaction(
    this.db,
  );

  // ignore: strict_raw_type
  static Transaction get current {
    // ignore: strict_raw_type
    Transaction transaction;

    try {
      transaction = use(transactionKey);
      // ignore: strict_raw_type
    } on MissingDependencyException catch (_) {
      throw TransactionNotInScopeException();
    }

    return transaction;
  }

  final Db db;

  // ignore: strict_raw_type
  static final ScopeKey<Transaction> transactionKey =
      // ignore: strict_raw_type
      ScopeKey<Transaction>('transaction');

  Future<R?> run(Future<R> Function() action) async {
    /// run using a transaction
    final result = db.transaction(() async => action());
    return result;
  }
}



class TransactionNotInScopeException implements Exception {}

class Db {
  R transaction<R>(Future<R> Function() param0) => 1 as R;

  void query(String s, List<Object?> list) {}
}

class DbPool {
  Db obtain() => Db();

  void release(Db db) {}
}

enum LicenseType { pro, team, enterprise }

/// calculate the license fee
Money getLicenseFee() {
  switch (use(licenseType)) {
    case LicenseType.pro:
      return Money.parse(r'$10.00', code: 'USD');
    case LicenseType.team:
      return Money.parse(r'$15.00', code: 'USD');
    case LicenseType.enterprise:
      return Money.parse(r'$20.00', code: 'USD');
  }
}
