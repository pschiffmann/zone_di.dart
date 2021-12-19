part of zone;

typedef Generator = dynamic Function();

class Scope {
  Scope();

  final provided = <ScopeKey<dynamic>, dynamic>{};
  final _factories = <ScopeKey<dynamic>, Generator>{};

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

  /// Injects a [factory] generated value into the [Scope].
  ///
  /// Factory functions may [use] values from other factories
  /// registered within the same [Scope].
  ///
  /// Each factory is eagerly called when [Scope.run] is called
  /// and are fully resolved when the [Scope.run]'s s action is called.
  void factory<T>(ScopeKey<T> key, T Function() factory) {
    if (_factories.containsKey(key)) {
      throw DuplicateDependencyException(key);
    }
    _factories.putIfAbsent(key, () => factory);
  }

  /// Runs [action] within the defined [Scope].
  ///
  ///
  R run<R>(R Function() action) {
    _resolveEagerFactories();

    return runZoned(action, zoneValues: {
      Injector: Injector(provided.map<ScopeKey<dynamic>, dynamic>(
          (t, dynamic v) =>
              MapEntry<ScopeKey<dynamic>, dynamic>(t, t._cast(v)))),
    });
  }

  void _resolveEagerFactories() {
    final injector = FactoryInjector(_factories);
    runZoned(() {
      injector.zone = Zone.current;
      // Cause [injector] to call all factories.
      for (final key in _factories.keys) {
        value<dynamic>(key, injector.get<dynamic>(key));
      }
    }, zoneValues: {Injector: injector});
  }

  static T use<T>(ScopeKey<T> key) => _use(key);
}
