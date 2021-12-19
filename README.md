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

# use
To obtain a registered value we can call either of the two forms of `use`.
The two forms are equivalent and exist simply for convenience.

```dart
     var age = use(ageKey);
     var name = Scope.use(ageKey);
```

The first version is consice whilst the second version provides better documentation.

ScopeKeys are typed as the result of `use` is also typed.


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


# Async calls

Scopes also work across asynchronous calls – multiple scopes can be executed concurrently without values leaking from one context into the other.

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
Future<void> main() async {
  await Scope()
     ..value<int>(emphasisToken, 1)
     .run(() async {
          final names = ['Alice', 'Bob', 'John'];

         await Scope()
         ..value<String>(greetingToken, 'Hello')
         .run(() async {
           final greeter = Greeter();
           for (final name in names) {
             greeter.greet(name);
             await delay1Sec();
           }
         });

         await Scope()
          ..value<String>(greetingToken, 'Goodbye')
          .run(() async {
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

# Factories and Generators

Scope allows you to define values based on factory or generator methods.

## factory
A factory value is simply a value that is provided by making a call to a function rather than providing a fixed value.

```dart
Scope()
..value<String>(nameKey, 'brett')
..value<DateTime>(dobKey, DateTime(year: 2000, month: 1, day 1)
..factory<String>(ageKey, () => DateTime.now().difference(use(dobKey)).inYears) // called only once.
..run(() {
     print('age: ${use(ageKey)}');
 });
 ```
 
 The factory value is calculated once by calling the method passed to the `factory` method.
 The factory method is called when the `run` method is called.  The calcualated factory value is then fixed for the life of the Scope.
 
 You can think of this as eager evaluation of the factory value.
 
 ## generator
  
 A generator value is registered in a similar way to the factory value. The difference is that the generator method is called each time the `use` method is called for the generators ScopeKey.
 
 
```dart
Scope()
..value<String>(nameKey, 'brett')
..value<DateTime>(dobKey, DateTime(year: 2000, month: 1, day 1)
..generator<String>(ageKey, () => DateTime.now().difference(use(dobKey)).inYears) // called each time `use(ageKey)` is called within this Scope.
..run(() {
     print('age: ${use(ageKey)}');
 });
 ```
 
 A generator value is reclaculated each time the `use` method is called for the registed ScopeKey and it is not calculated until the `use` method is called.
 
 You can think of this as lazy evalutation of the generator value.
 
 A generator can be used to recalcuate a value each time it is used and could be used to provide a sequence of values (such as a counter or a random number generator).


## How it works

To make values registered to the Scope available to `use()` calls, this package uses [zones](https://api.dartlang.org/stable/dart-async/Zone-class.html).
That means it can avoid global mutable state and the edge cases that typically come with it.


## How to use this package / best practices

Here are a few tips in no particular order.

---

Scope is not a substitue for the likes of Provider which works to provide values for your Flutter BuildContext. The Flutter build method isn't called on your stack (as its called by the Flutter framework) and Scope only works for methods calls nested within the Scope's run method.

Scope is intended for use cases where you create some resource at the top level and then need access to that resource way down in your call hierachy and you don't want to have to pass the value all the way down.

Consider using this package if you're writing command line applications, or pub packages that can be consumed on all platforms (Flutter, web, server).

---

You can call `use()` inside class constructors, in individual methods or even top-level functions outside of any class.

The only criteria is that when you call 'use' a Scope can be found in some parent method/function somewhere on the call stack.

---

The return value of the run action is passed through by `provide()`.
You can use this to instantiate a single class or call a single function that `inject()`s values:

```dart
void main() {
  final greeter =
      Scope()
          ..value<String>(greetingToken, 'Hello')
          ..value<int>(emphasisToken,  1)
          .run<Greeter>(Greeter());

  greeter.greet('world'); // `greeter` can now be used outside of the context
                          // function.
}
```

---

Other people can't see what your values you register in a Scope.
Make sure to explicitly list all dependencies of your class or function in its doc comment!
Remember to also include transitive dependencies – if your function instantiates a class with a dependency on `fooToken`, and your function doesn't provide a value for it, then your function should also list that token as its dependency.

---

If you use Scope in your published pub packages and expose the `use` to the package consumer, consider writing your own specialized `Scope()` and 'use' functions like this:

```dart
import 'package:meta/meta.dart' show required;
import 'package:scope/scope.dart' as scope;

final dbKey = ScopeKey<Db>();

// provide a transacition class that acquires a db cnnection
class Transaction
{
     void run(void Function() action)
     {
          var db = DbPool.acquire();
          Scope()
             ..value(dbKey, db)
             ..run(action);
             
           DbPool.release(db);
     }
    
     /// To access the db inscope for this transaction
     static DB db() => use(dbKey);
}


/// 
void main() 
{
     
     Transaction().run() {
          createUser();
        });
 }
 
 void createUser() {
       /// get the db this transaction is using.
       var db = Transation.db();
       db.insertUser();
}

```

This way, a consumer of your package doesn't have to look up what `ScopeKey`s are, and gets a type-safe list of all of your public dependencies at a glance.

