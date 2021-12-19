# Scope

Scope provides dependency injection for Dart applications
allowing you to inject values into a scope and then access from any method called within that scope.

Scope is not a replacement for the likes of Provider. Provider does dependency injection for your BuildContext whilst Scope provides di for your call stack.

For Java developers Scope provides similar functionality to a thread local variables

Authors: Philipp Schiffmann <philippschiffmann93@gmail.com>
     S. Brett Sutton

Scope is a reimagining of Philipp's zone_id package.
All credit goes to Phillipp's original implementation without which Scope wouldn't exist.



## API overview
The Scope API uses a builder pattern allowing you to register any number of strictly typed  variables.

You can then use any of the variables from any method called from within the Scope.

```dart
Scope()
    ..value<int>(ageKey, 18)
    ..value<String>(nameKey, 'brett')
    ..run(() {
        var age = use(ageKey);
        var name = use(nameKey);
    });
```

Scoped values are essentially stored as a typed map.
To store a value you must create a typed key:

```dart
final ageKey = ScopeKey<int>();
final nameKey = ScopeKey<String>();
```

Keys are declared at globally and it's is
standard practice to place you Keys in a separate dart library.

Scopes can be nested with the same key 
used at each level.

When you use a key within a nested Scoped
the value from the closest scope is returned.

If the key isn't in the nearest Scope we search up thorough parent scopes.

```dart
  Scope()
    ..value<int>(ageKey, 18)
    ..value<String>(nameKey, 'brett')
    ..run(() {
      var age = use(ageKey);
      var name = use(nameKey);
      Scope()
        ..value<int>(ageKey, 21)
        ..run(() {
          var age = use(ageKey);
          var name = use(nameKey);
    });
```



The three main exports of this package are `Token`, `provide()` and `inject()`.
Use tokens to declare dependencies that can be injected.

```dart
final greetingToken = Token<String>('my_package.greeting');
final emphasisToken = Token<int>('my_package.emphasis');
```

Unlike many other dependency injection frameworks, this package doesn't expose a _Container_ or _Injector_ class from which dependencies could be obtained.
Instead, the current value of a token can be looked up with a call to the top-level function `inject()`.

```dart
class Greeter {
  Greeter()
      : greeting = inject(greetingToken),
        emphasis = inject(emphasisToken);

  final String greeting;
  final int emphasis;

  void greet(String name) {
    print('$greeting, $name${"!" * emphasis}');
  }
}
```

Values are made available for injection by passing them to the top-level function `provide()`, together with a context callback function.
The function will be called immediately, and the (token, value) associations exist only inside of the context of this call tree.

```dart
void main() {
  provide({
    greetingToken: 'Hello',
    emphasisToken: 1,
  }, () {
    Greeter().greet('world'); // 'Hello, world!'
  });

  Greeter().greet('you'); // throws: `MissingDependencyException`, because the
                          // `inject()` call inside of the `Greeter` constructor
                          // was made outside of a `provide()` context.
                          // The previously provided values don't leak out from
                          // their context.
}
```

Different values can be provided to different parts of the program for the same token.
`provide()` contexts can be nested, and inner values shadow outer ones for the same token.
In this way, token lookup works analogous to name lookup in functions (local variable shadows function parameter, shadows class property, shadows global variable), except that it works across the boundaries of the current function.

```dart
void main() {
  provide({
    greetingToken: 'Hello',
    emphasisToken: 1,
  }, () {
    provide({greetingToken: 'Good day'}, () {
      Greeter().greet('Philipp'); // 'Good day, Philipp!'
    });

    provide({emphasisToken: 3}, () {
      Greeter().greet('Paul'); // 'Hello, Paul!!!'
    });
  });
}
```

Notice that this even works for asynchronous code – multiple `provide()` contexts can be executed concurrently without values leaking from one context into the other.

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
  provide({emphasisToken: 1}, () {
    final names = ['Alice', 'Bob', 'John'];

    provide({greetingToken: 'Hello'}, () async {
      final greeter = Greeter();
      for (final name in names) {
        greeter.greet(name);
        await delay1Sec();
      }
    });

    provide({greetingToken: 'Goodbye'}, () async {
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
