import 'dart:async';
import 'dart:collection';

enum SentinelValues { noValue }

class Token<T> {
  Token(this._debugName) : _defaultValue = SentinelValues.noValue;
  Token.withDefault(this._debugName, T defaultValue)
      : _defaultValue = defaultValue;

  final String _debugName;
  final Object _defaultValue;

  T _cast(dynamic v) => v as T;

  @override
  String toString() => 'Token($_debugName)';
}

typedef ValueFactory<T> = T Function();

/// Throws a [CastError] if [values] contains a (`Token<T>`, value) pair where
/// value is not assignable to `T`.
R provide<R>(Map<Token, dynamic> values, R Function() f) =>
    runZoned(f, zoneValues: {
      Injector: Injector(values.map((t, v) => MapEntry(t, t._cast(v)))),
    });

/// Alias of `provide({token: value}, f)`.
R provideSingle<T, R>(Token<T> token, T value, R Function() f) =>
    runZoned(f, zoneValues: {
      Injector: Injector({token: value})
    });

///
R provideFactories<R>(Map<Token, ValueFactory> factories, R Function() f) {
  final injector = FactoryInjector(factories);
  runZoned(() {
    injector.zone = Zone.current;
    for (final token in factories.keys) injector.get(token);
  }, zoneValues: {Injector: injector});

  return provide(injector.values, f);
}

/// Returns the value provided for [token], or the tokens default value if no
/// value was provided.
T inject<T>(Token<T> token) =>
    ((Zone.current[Injector] as Injector) ?? const Injector.empty()).get(token);

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
    if (token._defaultValue != SentinelValues.noValue) {
      return token._defaultValue;
    }
    throw MissingDependencyException(token);
  }
}

class FactoryInjector extends Injector {
  FactoryInjector(this.factories) : super({});

  final Map<Token, ValueFactory> factories;
  final underConstruction = LinkedHashSet<Token>();
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
      values[token] = zone.run(factories[token]);
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

class CircularDependencyException implements Exception {
  CircularDependencyException(this.tokens);
  final List<Token> tokens;

  @override
  String toString() => 'The factories for these tokens depend on each other: '
      '${tokens.join(" -> ")} -> ${tokens.first}';
}
