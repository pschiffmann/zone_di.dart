library scope;

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'exceptions.dart';

part 'scope_key.dart';
part 'injector.dart';
part 'singleton_injector.dart';

typedef Generator = dynamic Function();

class Scope {
  Scope([String? debugName]) {
    _debugName = debugName ?? 'Unnamed Scope - pass debugName to ctor';
  }

  @override
  String toString() => _debugName;

  late final String _debugName;

  final provided = <ScopeKey<dynamic>, dynamic>{};
  final _singletons = <ScopeKey<dynamic>, Generator>{};
  final _generators = <ScopeKey<dynamic>, Generator>{};

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

  @Deprecated('Use single')
  void factory<T>(ScopeKey<T> key, T Function() factory) =>
      single(key, factory);

  /// Injects a [single] value into the [Scope].
  ///
  /// Singletons may [use] [value]s, other [single]s
  /// and [sequence]s registered within the same [Scope].
  ///
  /// Each [single] is eagerly called when [Scope.run] is called
  /// and are fully resolved when the [Scope.run]'s s action is called.
  void single<T>(ScopeKey<T> key, T Function() factory) {
    if (_singletons.containsKey(key)) {
      throw DuplicateDependencyException(key);
    }
    _singletons.putIfAbsent(key, () => factory);
  }

  /// Injects a generated value into the [Scope].
  ///
  /// The [sequence]'s [factory] method is called each time [use]
  /// for the [key] is called.
  ///
  /// The difference between [single] and [sequence] is that
  /// for a [single] the [factory] method is only called once where as
  /// the [sequence]s [factory] method is called each time [use] for
  /// the [sequence]'s key is called.
  ///
  /// The [generator] [factory] method is NOT called when the [run] method
  /// is called.
  ///
  void sequence<T>(ScopeKey<T> key, T Function() factory) {
    if (_generators.containsKey(key)) {
      throw DuplicateDependencyException(key);
    }
    value<dynamic>(key, factory);
  }

  /// Runs [action] within the defined [Scope].
  R run<R>(R Function() action) {
    _resolveSingletons();

    return runZoned(action, zoneValues: {
      Injector:
          Injector(provided.map<ScopeKey<dynamic>, dynamic>((t, dynamic v) {
        if (v is Function) {
          return MapEntry<ScopeKey<dynamic>, dynamic>(t, t._castFunction(v));
        } else {
          return MapEntry<ScopeKey<dynamic>, dynamic>(t, t._cast(v));
        }
      })),
    });
  }

  void _resolveSingletons() {
    final injector = SingletonInjector(_singletons);
    runZoned(() {
      injector.zone = Zone.current;
      // Cause [injector] to call all factories.
      for (final key in _singletons.keys) {
        /// Resolve the singlton by calling its factory method
        /// and adding it as a value.
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

/// Returns true if [key] is contained within the current scope.
/// For nullable types even if the value is null [hasScopeKey]
/// will return true if a value was injected.
bool hasScopeKey<T>(ScopeKey<T> key) => _hasScopeKey(key);

/// Returns true if [key] is contained within the current scope
bool _hasScopeKey<T>(ScopeKey<T> key) {
  var _hasScopeKey = true;
  final injector =
      (Zone.current[Injector] as Injector?) ?? const Injector.empty();
  if (injector.hasKey(key)) {
    // final value = injector.get(key);
    // if (isNullable<T>() && value == null) {
    //   _hasScopeKey = false;
    // }
    _hasScopeKey = true;
  } else {
    _hasScopeKey = false;
  }
  return _hasScopeKey;
}

/// Returns true if the caller is running within a [Scope]
bool isWithinScope() => _isWithinScope();

bool _isWithinScope() => Zone.current[Injector] != null;
