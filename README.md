# Scope

Scope provides dependency injection (DI) for Dart applications
allowing you to inject values into a scope and then 'use' those dependencies from any method (or constructor) called within that scope.

Scope is not a replacement for the likes of Provider. Provider does dependency injection for your BuildContext whilst Scope provides DI for your call stack.

For Java developers Scope provides similar functionality to a thread local variables

Authors: Philipp Schiffmann <philippschiffmann93@gmail.com>
     S. Brett Sutton

Scope is a reimagining of Philipp's zone_id package.
All credit goes to Phillipp's original implementation without which Scope wouldn't exist.



## API overview
The Scope API uses a builder pattern allowing you to register any number of strictly typed values.

You can then 'use' the registered values from any method called from within the Scope.

The registered values are essentially stored in a map and are retrieved using a globally defined key.


```dart
Scope()
    ..value<int>(ageKey, 18)
    ..value<String>(nameKey, 'brett')
    ..run(() {
        var age = use(ageKey);
        var name = use(nameKey);
    });
```
In the above example we register two values:
* an int with a key 'ageKey' and a value 18.
* a String with a key 'nameKey' and a value of 'brett'.

The age and name values are then retrieved using the `use` method and the ScopeKey they where stored with.


## ScopeKey
To store and use a value you must create a typed key for each value using a ScopeKey:

```dart
final ageKey = ScopeKey<int>();
final nameKey = ScopeKey<String>();
final monthKey = ScopeKey<String>();
```

As the ScopeKey is typed the values returned from the `use` call are also correctly typed.

Keys are declared globally and it's is standard practice to place you Keys in a separate dart library as they need to be available at both the registration site and the use site.

# Example

We start by creating a client that will 'use' values registered into the Scope.
```dart
class Greeter {
  Greeter()
      : greeting = use(greetingToken),
        emphasis = use(emphasisToken);

  final String greeting;
  final int emphasis;

  void greet(String name) {
    print('$greeting, $name${"!" * emphasis}');
  }
}
```

Values are made available for registering them with a `Scope`.
The function will be called immediately, and the (token, value) associations exist only inside of the context of this call tree.

```dart
void main() {
  Scope()
    ..value<String>(greetingToken, 'Hello')
    ..value<int>(emphasisToken, 1)
    ..run(() {
    // The greet method calls `use` to retrieve the registered values
    Greeter().greet('world'); // 'Hello, world!'
  });

  Greeter().greet('you'); // throws: `MissingDependencyException`, because 
                          // `use()` is called outside the `Scope.run` method.
                          // The previously registered values arn't available
                          // outside of the scope.
}
```

# Nesting

Scopes can also be nested with the same key used at each level.

When you `use` a key within a nested Scoped the value from the closest scope is returned.

If the key isn't in the immediate Scope we search up thorough parent scopes.

```dart
void main() {

  // parent scope
  Scope()
    ..value<String>(greetingToken, 'Hello')
    ..value<int>(emphasisToken,  1)
     ..run(() {
    
          /// Nest child Scope
          Scope()
          ..value<String>(greetingToken, 'Good day')
          ..run(() {
               Greeter().greet('Philipp'); // 'Good day, Philipp!'
          });

         /// Also nested witin the parent scope
         Scope()
          ..value<int>(emphasisToken, 3)
          ..run(() {
               Greeter().greet('Paul'); // 'Hello, Paul!!!'
         });
  });
}
```

Notice that this even works for asynchronous code – multiple scopes can be executed concurrently without values leaking from one context into the other.

```dart
Future delay1Sec() => Future.delayed(Duration(seconds: 1));

/// Will print:
///
///     Hello, Alice!
///     Goodbye, Alice!
///     Hello, Bob!
///     Goodbye, Bob!
///     Hello, John!
///     Goodbye, John!
void main() {
  Scope()
     ..value<int>(emphasisToken, 1)
     ..run(() {
          final names = ['Alice', 'Bob', 'John'];

         Scope()
         ..value<String>(greetingToken, 'Hello')
         ..run(() async {
           final greeter = Greeter();
           for (final name in names) {
             greeter.greet(name);
             await delay1Sec();
           }
         });

         Scope()
         ..value<String>(greetingToken, 'Goodbye')
         ..run(() async {
                final greeter = Greeter();
                await Future.delayed(Duration(milliseconds: 500));
                for (final name in names) {
                  greeter.greet(name);
                  await delay1Sec();
                }
         });
     });
}
```

Finally, there's also `provideFactories()` that constructs token values from the given factory functions and handles dependencies between the factories.
For more details on that and the other functions, see the [API docs](https://pub.dev/documentation/zone_di/latest/).

## How it works

To make `provide()` arguments available in `inject()`, this package uses [zones](https://api.dartlang.org/stable/dart-async/Zone-class.html).
That means it can avoid global mutable state and the edge cases that typically come with it.
For a longer explanation, I wrote a blog post about it [here](https://medium.com/@philippschiffmann/dependency-injection-in-dart-using-zones-45d6028eb1da).

## A note on naming

Since writing this package I have learned that the name "dependency injection" explicitly refers to the approach to use a _Container_ for managing objects, and that the dependencies of a class should be visible from its public API, mainly its constructor parameters or public setters.
Since this API doesn't follow these conventions, the _di_ in the package name is a misnomer, and I'm sorry if I've lured you onto this README with false promises.
I hope it can be of use to you regardless.

## How to use this package / best practices

Here are a few tips in no particular order.

---

If you're already using a framework that ships with a dependency injection mechanism, that one is probably better optimized for your use case.
In particular, Angular has its own [annotation-based DI system](https://angulardart.dev/guide/hierarchical-dependency-injection), and Flutter has [inherited widgets](https://api.flutter.dev/flutter/widgets/InheritedWidget-class.html).
Both support multiple concurrent, nested scopes likes this package; but scopes are tied to components/widgets rather than function calls, which is most likely what you want.

Instead, consider using this package if you're writing command line applications, or pub packages that can be consumed on all platforms (Flutter, web, server).

---

You can use `inject()` not only inside of class constructors, but also in individual methods or even top-level functions outside of any class.

---

The return value of the context function is passed through by `provide()`.
You can use this to instantiate a single class or call a single function that `inject()`s values:

```dart
void main() {
  final greeter =
      provide({greetingToken: 'Hello', emphasisToken: 1}, () => Greeter());

  greeter.greet('world'); // `greeter` can now be used outside of the context
                          // function.
}
```

---

Other people can't see what your classes and functions `inject()`.
Make sure to explicitly list all dependencies of your class or function in its doc comment!
Remember to also include transitive dependencies – if your function instantiates a class with a dependency on `fooToken`, and your function doesn't provide a value for it, then your function should also list that token as its dependency.

---

If you use zone_di in your published pub packages and expose the injection to the package consumer, consider writing your own specialized `provide()` function like this:

```dart
import 'package:meta/meta.dart' show required;
import 'package:zone_di/zone_di.dart' as zone_di;

final fooToken = Token<String>('my_package.foo');
final barToken = Token<int>('my_package.bar');

void provide(void Function() f, {@required String foo, int bar}) {
  zone_di.provide({fooToken: foo, barToken: bar}, f);
}
```

This way, a consumer of your package doesn't have to look up what `Token`s are, and gets a type-safe list of all of your public dependencies at a glance.

## Special thanks

A big thank you goes to Paul Hammant for his insightful feedback and criticism.
