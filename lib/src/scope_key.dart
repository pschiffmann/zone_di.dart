part of scope;

/// The only purpose of [ScopeKey]s is to be unique so that they can be used to
/// uniquely identify injected values. [ScopeKey]s are opaque – you are
/// not supposed to read any other information from them except their identity.
/// You must not extend or implement this class.
///
/// The `debugName` is only used in error messages. We recommend that
/// you use a debugName of the form:
/// `package_name.library_name.variableName`
///
/// If a key is created with a default value, it will be returned by [use]
/// when no value was provided for this key. `null` is a valid default value,
/// provided the [T] is nullable (e.g. String?), and is distinct from no value.
///
/// The type argument [T] is used to infer the return type of [use].
@sealed
class ScopeKey<T> {
  ScopeKey([this._debugName]) : _defaultValue = Sentinel.noValue {
    _debugName ??= T.runtimeType.toString();
  }
  ScopeKey.withDefault(T defaultValue, this._debugName)
      : _defaultValue = defaultValue {
    _debugName ??= T.runtimeType.toString();
  }

  String? _debugName;
  final Object? _defaultValue;

  T _cast(dynamic v) => v as T;

  @override
  String toString() => 'ScopeKey(${_debugName!})';
}

enum Sentinel {
  /// Used to indicate that a [ScopeKey] has no default value – which is
  /// different from a default value of `null`.
  noValue
}
