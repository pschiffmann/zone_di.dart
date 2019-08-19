import 'dart:async';

class _NoValue {}

class Token<T> {
  Token(this._debugName) : _defaultValue = _NoValue;
  Token.withDefault(this._debugName, T this._defaultValue);

  final String _debugName;
  final Object _defaultValue;

  T _cast(dynamic v) => v as T;

  @override
  String toString() => 'Token($_debugName)';
}

typedef ValueFactory<T> = T Function();

R provide<R>(Map<Token, dynamic> values, R Function() f) =>
    runZoned(f, zoneValues: {
      Injector: Injector(values.map((t, v) => t._cast(v))),
    });

R provideSingle<T, R>(Token<T> token, T value, R Function() f) =>
    runZoned(f, zoneValues: {token: value});

R provideFactories<R>(Map<Token, ValueFactory> factories, R Function() f) {
  final injector = FactoryInjector(factories);
  for (final token in factories.keys) injector.get(token);
  return provide(injector.values, f);
}

T inject<T>(Token<T> token) =>
    ((Zone.current[Injector] as Injector) ?? Injector.root).get(token);

class Injector {
  Injector(this.values);
  const Injector.empty() : values = const {};

  final Map<Token, Object> values;

  T get<T>(Token<T> token) {
    if (values.containsKey(token)) return token._cast(values[token]);
    final parent = Zone.current.parent[Injector] as Injector;
    if (parent != null) return parent.get(token);
    if (token._defaultValue != _NoValue) return token._defaultValue;
    throw MissingDependencyException(token);
  }

  static Injector forZone(Zone zone) =>
      (zone[Injector] as Injector) ?? const Injector.empty();

  static Injector parent() =>
      (Zone.current[Injector] as Injector) ?? const Injector.empty();
}

class FactoryInjector extends Injector {
  FactoryInjector(this.factories)
      : context = Zone.current,
        super({});

  final Map<Token, ValueFactory> factories;
  final Zone context;
  final Set<Token> factoriesCalled = {};

  @override
  T get<T>(Token<T> token) {
    if (values.containsKey(token)) return values[token];
    if (!factories.containsKey(token)) return super.get(token);
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
