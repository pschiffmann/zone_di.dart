import 'dart:async';

final someToken = Token<String>('someToken');

void main() {
  provideSingle(someToken, 'hello world', () {
    final s = inject(someToken);
    print(s);
  });
  provide({someToken: 'foo'}, () {
    print(inject(someToken));
  });
}

class _NoValue {}

class Token<T> {
  Token(this._debugName) : _defaultValue = _NoValue;
  Token.withDefault(this._debugName, T defaultValue)
      : _defaultValue = defaultValue;

  final dynamic _debugName;
  final Object _defaultValue;

  T _cast(dynamic v) => v as T;

  @override
  String toString() => 'Token($_debugName)';
}

R provideSingle<T, R>(Token<T> token, T value, R Function() f) =>
    runZoned(f, zoneValues: {token: value});

R provide<R>(Map<Token, dynamic> values, R Function() f) =>
    runZoned(f, zoneValues: {
      _Injector: _Injector(values.map((t, v) => t._cast(v))),
    });

T inject<T>(Token<T> token) =>
    ((Zone.current[_Injector] as _Injector) ?? _Injector.root).get(token);

class _Injector {
  _Injector(this.values);
  const _Injector.empty() : values = const {};

  final Map<Token, Object> values;

  T get<T>(Token<T> token) {
    if (values.containsKey(token)) return token._cast(values[token]);
    final parent = Zone.current.parent[_Injector] as _Injector;
    if (parent != null) return parent.get(token);
    if (token._defaultValue != _NoValue) return token._defaultValue;
    throw MissingDependencyException(token);
  }

  static const root = _Injector.empty();

  static _Injector forZone(Zone zone) =>
      (zone[_Injector] as _Injector) ?? const _Injector.empty();
}

class MissingDependencyException implements Exception {
  MissingDependencyException(this.token);
  final Token token;
}
