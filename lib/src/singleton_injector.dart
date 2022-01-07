part of scope;

/// Used by [Scope.single].
class SingletonInjector extends Injector {
  SingletonInjector(this.factories) : super(<ScopeKey<dynamic>, dynamic>{});

  final Map<ScopeKey<dynamic>, ValueFactory<dynamic>> factories;

  /// All keys from [factories] for which the factory function has been called
  /// and not yet returned. Iteration order represents call order.
  // ignore: prefer_collection_literals
  final underConstruction = LinkedHashSet<ScopeKey<dynamic>>();

  /// The zone that holds the injected values in this Scope
  /// ```
  ///   zone[Injector] == this
  /// ```
  ///
  /// [Scope.single] and [Scope.sequence] values are run in this zone,
  /// so [Scope]s nested in  [Scope.single]  and [Scope.sequence] methods
  /// can't shadow keys from this [Scope].
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
