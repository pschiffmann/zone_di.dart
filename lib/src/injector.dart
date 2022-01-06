part of scope;

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

  bool hasKey<T>(ScopeKey<T> key) {
    if (values.containsKey(key)) {
      return true;
    }
    if (parent != null) {
      return parent!.hasKey(key);
    }
    if (key._defaultValue != Sentinel.noValue) {
      return true;
    }

    return false;
  }
}
