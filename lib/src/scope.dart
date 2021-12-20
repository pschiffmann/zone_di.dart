library scope;

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'exceptions.dart';

part 'scope_key.dart';
part 'injector.dart';
part 'factory_injector.dart';

typedef Generator = dynamic Function();

class Scope {
  Scope();

  final provided = <ScopeKey<dynamic>, dynamic>{};
  final _factories = <ScopeKey<dynamic>, Generator>{};

  /// Injects [value] into the [Scope].
  ///
  /// The [value] can be retrieve by calling
  /// [use] from anywhere within the action
  /// method provided to [run]
  void value<T>(ScopeKey<T> key, T value) {
    if (provided.containsKey(key)) {
      throw DuplicateDependencyException(key);
    }
    provided.putIfAbsent(key, () => value);
  }

  /// Injects a [factory] generated value into the [Scope].
  ///
  /// Factory functions may [use] values from other factories
  /// registered within the same [Scope].
  ///
  /// Each factory is eagerly called when [Scope.run] is called
  /// and are fully resolved when the [Scope.run]'s s action is called.
  void factory<T>(ScopeKey<T> key, T Function() factory) {
    if (_factories.containsKey(key)) {
      throw DuplicateDependencyException(key);
    }
    _factories.putIfAbsent(key, () => factory);
  }

  /// Injects a generated value into the [Scope].
  ///
  /// The generator [factory] is called each time [use] for the [key].
  ///
  /// The difference between [factory] and [generator] is that for a [factory]
  /// the [factory] method is only called once where as the [generator]s
  /// [factory] method is called repeatedly.
  ///
  /// The [generator] [factory] method is NOT called when the [run] method
  /// is called.
  ///
  /// !!!!Note: currently generators are not implmented!!!!
  void generator<T>(ScopeKey<T> key, T Function() factory) {
    throw UnimplementedError('generators are not currently supported');
  }

  /// Runs [action] within the defined [Scope].
  R run<R>(R Function() action) {
    _resolveEagerFactories();

    return runZoned(action, zoneValues: {
      Injector: Injector(provided.map<ScopeKey<dynamic>, dynamic>(
          (t, dynamic v) =>
              MapEntry<ScopeKey<dynamic>, dynamic>(t, t._cast(v)))),
    });
  }

  void _resolveEagerFactories() {
    final injector = FactoryInjector(_factories);
    runZoned(() {
      injector.zone = Zone.current;
      // Cause [injector] to call all factories.
      for (final key in _factories.keys) {
        value<dynamic>(key, injector.get<dynamic>(key));
      }
    }, zoneValues: {Injector: injector});
  }

  static T use<T>(ScopeKey<T> key) => _use(key);

  /// Returns true if [key] is contained within the current scope
  static bool hasScopeKey<T>(ScopeKey<T> key) => _hasScopeKey(key);

  /// Returns true if the caller is running within a [Scope]
  static bool isWithinScope() => _isWithinScope();
}

typedef ValueFactory<T> = T? Function();

/// Returns the value provided for [key], or the keys default value if no
/// value was provided.
///
/// May throw [MissingDependencyException] or [CircularDependencyException].
T use<T>(ScopeKey<T> key) => _use(key);

/// Returns the value provided for [key], or the keys default value if no
/// value was provided.
///
/// May throw [MissingDependencyException] or [CircularDependencyException].
T _use<T>(ScopeKey<T> key) {
  final injector =
      (Zone.current[Injector] as Injector?) ?? const Injector.empty();
  final value = injector.get(key);

  return value;
}

/// Returns true if [T] was declared as a nullable type (e.g. String?)
bool isNullable<T>() => null is T;

/// Returns true if [key] is contained within the current scope
bool hasScopeKey<T>(ScopeKey<T> key) => _hasScopeKey(key);

/// Returns true if [key] is contained within the current scope
bool _hasScopeKey<T>(ScopeKey<T> key) {
  var _hasScopeKey = true;
  final injector =
      (Zone.current[Injector] as Injector?) ?? const Injector.empty();
  try {
    final value = injector.get(key);
    if (isNullable<T>() && value == null) {
      _hasScopeKey = false;
    }
  } on MissingDependencyException<T> catch (_) {
    _hasScopeKey = false;
  }
  return _hasScopeKey;
}

/// Returns true if the caller is running within a [Scope]
bool isWithinScope() => _isWithinScope();

bool _isWithinScope() => Zone.current[Injector] != null;
