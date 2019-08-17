import 'dart:async';

const someToken = Token<String>('someToken');

void main() {
  provide(someToken, 'hello world', () {
    final s = inject(someToken);
    print(s);
  });
  provideAll({someToken: 'foo'}, () {
    print(inject(someToken));
  });
}

class Token<T> {
  const Token(this._identifier)
      : _defaultValue = null,
        _hasDefaultValue = false;
  const Token.withDefaultValue(this._identifier, [this._defaultValue])
      : _hasDefaultValue = true;

  final dynamic _identifier;
  final T _defaultValue;
  final bool _hasDefaultValue;

  T _cast(dynamic v) => v as T;

  @override
  String toString() => 'Token($_identifier)';
}

R provide<T, R>(Token<T> token, T value, R Function() f) =>
    runZoned(f, zoneValues: {token: value});

R provideAll<R>(Map<Token, dynamic> values, R Function() f) =>
    runZoned(f, zoneValues: values..forEach((t, v) => t._cast(v)));

T inject<T>(Token<T> token) {
  final zoneValue = Zone.current[token];
  if (zoneValue != null) return token._cast(zoneValue);
  if (token._hasDefaultValue) return token._defaultValue;
  throw Exception();
}
