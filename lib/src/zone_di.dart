import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

enum Sentinel {
  /// Used to indicate that a [Token] has no default value – which is different
  /// from a default value of `null`.
  noValue
}

/// The only purpose of tokens is to be unique so that they can be used to
/// uniquely identify injected values. Tokens are opaque – you are not supposed
/// to read any other information from them except their identity. You must not
/// extend or implement this class.
///
/// The `debugName` is only used in error messages. Strings with shape
/// `package_name.library_name.variableName` are recommended.
///
/// If a token is created with a default value, it will be returned by [inject]
/// when no value was provided for this token. `null` is a valid default value.
///
/// The type argument [T] is used to infer the return type of [inject].
@sealed
class Token<T> {
  Token(this._debugName) : _defaultValue = Sentinel.noValue;
  Token.withDefault(this._debugName, T defaultValue)
      : _defaultValue = defaultValue;

  final String _debugName;
  final Object _defaultValue;

  T _cast(dynamic v) => v as T;

  @override
  String toString() => 'Token($_debugName)';
}

typedef ValueFactory<T> = T Function();

/// Associates the tokens in [values] with the provided values inside of [f].
///
/// Throws a [CastError] if [values] contains a (`Token<T>`, value) pair where
/// value is not assignable to `T`. It is possible to provide `null` for a
/// token.
R provide<R>(Map<Token, dynamic> values, R Function() f) =>
    runZoned(f, zoneValues: {
      Injector: Injector(values.map((t, v) => MapEntry(t, t._cast(v)))),
    });

/// Alias of `provide({token: value}, f)`.
R provideSingle<T, R>(Token<T> token, T value, R Function() f) =>
    runZoned(f, zoneValues: {
      Injector: Injector({token: value})
    });

/// Eagerly calls [factories], then provides the results to [f]. Factory
/// functions may [inject] other values from [factories].
///
/// ```dart
/// provideFactories({
///   tokenA: () => 'hello',
///   tokenB: () => 'world',
///   tokenAB: () => inject(tokenA) + ' ' + inject(tokenB)
/// }, () {
///   assert(inject(tokenAB) == 'hello world');
/// });
/// ```
///
/// Note that factories can't [inject] tokens provided in another factory
/// function:
///
/// ```dart
/// provideFactories({
///   tokenX: () => provideSingle(
///         tokenY,
///         42,
///         () => inject(tokenZ) - 1,
///       ),
///   tokenZ: () {
///     // Will throw [MissingDependencyException] even though a value for
///     // `tokenY` was provided in `tokenX` factory.
///     return inject(tokenY) * 4;
///   }
/// }, () {});
/// ```
///
/// Each factory is called at most once. Throws a [CastError] if a factory
/// returns an object that doesn't match its token type. Throws a
/// [CircularDependencyException] if two factories try to mutually [inject] each
/// others tokens.
R provideFactories<R>(Map<Token, ValueFactory> factories, R Function() f) {
  final injector = FactoryInjector(factories);
  runZoned(() {
    injector.zone = Zone.current;
    // Cause [injector] to call all factories.
    factories.keys.forEach(injector.get);
  }, zoneValues: {Injector: injector});

  return provide(injector.values, f);
}

/// Returns the value provided for [token], or the tokens default value if no
/// value was provided.
T inject<T>(Token<T> token) =>
    ((Zone.current[Injector] as Injector) ?? const Injector.empty()).get(token);

/// Implements the token store and lookup mechanism. The Injector [Type] is used
/// as the key into a [Zone] to store the injector instance for that zone.
class Injector {
  Injector(this.values) : parent = Zone.current[Injector];
  const Injector.empty()
      : values = const {},
        parent = null;

  final Map<Token, Object> values;
  final Injector parent;

  T get<T>(Token<T> token) {
    if (values.containsKey(token)) return token._cast(values[token]);
    if (parent != null) return parent.get(token);
    if (token._defaultValue != Sentinel.noValue) {
      return token._defaultValue;
    }
    throw MissingDependencyException(token);
  }
}

/// Used by [provideFactories].
class FactoryInjector extends Injector {
  FactoryInjector(this.factories) : super({});

  final Map<Token, ValueFactory> factories;

  /// All tokens from [factories] for which the factory function has been called
  /// and not yet returned. Iteration order represents call order.
  final underConstruction = LinkedHashSet<Token>();

  /// The zone that contains this injector (`zone[Injector] == this`).
  ///
  /// [factories] are run in this zone, so [provide] calls in factory functions
  /// can't shadow tokens from [factories].
  Zone zone;

  @override
  T get<T>(Token<T> token) {
    if (!factories.containsKey(token)) return super.get(token);
    if (!values.containsKey(token)) {
      final underConstructionAlready = !underConstruction.add(token);
      if (underConstructionAlready) {
        throw CircularDependencyException(
            List.unmodifiable(underConstruction.skipWhile((t) => t != token)));
      }
      values[token] = token._cast(zone.run(factories[token]));
      assert(underConstruction.last == token);
      underConstruction.remove(token);
    }
    return values[token];
  }
}

/// Thrown by [inject] when no value has been [provide]d for [token] and it has
/// no default value.
class MissingDependencyException implements Exception {
  MissingDependencyException(this.token);

  final Token token;

  @override
  String toString() =>
      'MissingDependencyException: No value has been provided for $token, '
      'and it has no default value';
}

/// Thrown by [inject] when called inside a [provideFactories] callback and the
/// [tokens] factories try to mutually inject each other.
class CircularDependencyException implements Exception {
  CircularDependencyException(this.tokens);
  final List<Token> tokens;

  @override
  String toString() => 'CircularDependencyException: The factories for these '
      'tokens depend on each other: ${tokens.join(" -> ")} -> ${tokens.first}';
}
