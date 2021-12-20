# Scope

Scope provides dependency injection (DI) for Dart applications
allowing you to inject values into a scope and then 'use' those dependencies from any method (or constructor) called within that scope.

Scope is not a replacement for the likes of Provider. Provider does dependency injection for your BuildContext whilst Scope provides DI for your call stack.

For Java developers Scope provides similar functionality to a thread local variables

Authors: Philipp Schiffmann <philippschiffmann93@gmail.com>
     S. Brett Sutton

Scope is a reimagining of Philipp's zone_id package.
All credit goes to Phillipp's original implementation without which Scope wouldn't exist.


The best way to understand Scope is with an example:

```dart
void main() {
    /// create a Scope
    Scope()
    
    /// inject a value
    ..value<int>(ageKey, 18)
    
    /// run some code within the Scope
    ..run(() => a();
}
void a() => b();

/// `use` the injected value
void b() => print('You are ${use(ageKey)} years old');
```

See the scope documentation at:

https://scope.noojee.dev