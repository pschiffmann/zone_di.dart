import 'scope.dart';

/// Thrown by [use] when no value has been registered in the [Scope]
/// for [key] and it has no default value.
class MissingDependencyException<T> implements Exception {
  MissingDependencyException(this.key);

  final ScopeKey<T> key;

  @override
  String toString() =>
      'MissingDependencyException: No value has been provided for $key, '
      'and it has no default value';
}

/// Thrown by [use] when called inside a [Scope.factory] or [Scope.generator]
/// callback and the [keys] factories try to mutually inject each other.
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
