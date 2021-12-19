library zone;

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

part 'scope.dart';

enum Sentinel {
  /// Used to indicate that a [ScopeKey] has no default value – which is
  /// different from a default value of `null`.
  noValue
}

/// The only purpose of keys is to be unique so that they can be used to
/// uniquely identify injected values. ScopeKeys are opaque – you are not supposed
/// to read any other information from them except their identity. You must not
/// extend or implement this class.
///
/// The `debugName` is only used in error messages. Strings with shape
/// `package_name.library_name.variableName` are recommended.
///
/// If a key is created with a default value, it will be returned by [use]
/// when no value was provided for this key. `null` is a valid default value
/// and distinct from no value.
///
/// The type argument [T] is used to infer the return type of [use].
@sealed
class ScopeKey<T> {
  ScopeKey(this._debugName) : _defaultValue = Sentinel.noValue;
  ScopeKey.withDefault(this._debugName, T defaultValue)
      : _defaultValue = defaultValue;

  final String _debugName;
  final Object? _defaultValue;

  T _cast(dynamic v) => v as T;

  @override
  String toString() => 'ScopeKey($_debugName)';
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
bool hasScopeKey<T>(ScopeKey<T> key) {
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

// T? injectNullable<T>(ScopeKey<T> key) =>
//     ((Zone.current[Injector] as Injector?) ?? const Injector.empty())
//         .get(key);

/// Implements the key store and lookup mechanism. The Injector [Type] is used
/// as the key into a [Zone] to store the injector instance for that zone.
class Injector {
  Injector(this.values) : parent = Zone.current[Injector] as Injector?;
  const Injector.empty()
      : values = const <ScopeKey<dynamic>, dynamic>{},
        parent = null;

  final Map<ScopeKey<dynamic>, dynamic> values;
  final Injector? parent;

  T get<T>(ScopeKey<T> key) {
    if (values.containsKey(key)) {
      return key._cast(values[key]);
    }
    if (parent != null) {
      return parent!.get(key);
    }
    if (key._defaultValue != Sentinel.noValue) {
      return key._defaultValue as T;
    }

    if (!isNullable<T>()) {
      throw MissingDependencyException(key);
    }
    return null as T;
  }
}

/// Used by [Scope.factory].
class FactoryInjector extends Injector {
  FactoryInjector(this.factories) : super(<ScopeKey<dynamic>, dynamic>{});

  final Map<ScopeKey<dynamic>, ValueFactory<dynamic>> factories;

  /// All keys from [factories] for which the factory function has been called
  /// and not yet returned. Iteration order represents call order.
  // ignore: prefer_collection_literals
  final underConstruction = LinkedHashSet<ScopeKey<dynamic>>();

  /// The zone that contains this injector (`zone[Injector] == this`).
  ///
  /// [factories] are run in this zone, so [provide] calls in factory functions
  /// can't shadow keys from [factories].
  late Zone zone;

  @override
  T get<T>(ScopeKey<T> key) {
    if (!factories.containsKey(key)) {
      return super.get(key);
    }
    if (!values.containsKey(key)) {
      final underConstructionAlready = !underConstruction.add(key);
      if (underConstructionAlready) {
        throw CircularDependencyException(
            List.unmodifiable(underConstruction.skipWhile((t) => t != key)));
      }
      values[key] = key._cast(zone.run<T>(factories[key]! as T Function()));
      // ignore: prefer_asserts_with_message
      assert(underConstruction.last == key);
      underConstruction.remove(key);
    }
    return values[key] as T;
  }
}

/// Thrown by [use] when no value has been [provide]d for [key] and it has
/// no default value.
class MissingDependencyException<T> implements Exception {
  MissingDependencyException(this.key);

  final ScopeKey<T> key;

  @override
  String toString() =>
      'MissingDependencyException: No value has been provided for $key, '
      'and it has no default value';
}

/// Thrown by [use] when called inside a [provideFactories] callback and the
/// [keys] factories try to mutually inject each other.
class CircularDependencyException<T> implements Exception {
  CircularDependencyException(this.keys);
  final List<ScopeKey<T>> keys;

  @override
  String toString() => 'CircularDependencyException: The factories for these '
      'keys depend on each other: ${keys.join(" -> ")} -> ${keys.first}';
}

class DuplicateDependencyException<T> implements Exception {
  DuplicateDependencyException(this.key);

  final ScopeKey<T> key;

  @override
  String toString() => 'DuplicateDependencyException: '
      'The key $key has already been added to this Scope.';
}
