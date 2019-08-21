# zone_di

Dependency injection with a functional API that works without code generation, mirrors or passing around Injector objects.

## Usage

The three main exports of this package are `Token`, `provide()` and `inject()`.
Use tokens to declare dependencies that can be injected.
Then associate values to your tokens with `provide()`, and read them with `inject()`.

```dart
import 'package:zone_di/zone_di.dart';

final fooToken = Token<String>('my_package.fooToken');

class MyConsumer {
  final String foo;

  MyConsumer() : foo = inject(fooToken).toUpperCase();
}

void main() {
  provide(fooToken, 'Hello world', () {
    final consumer = MyConsumer();
    print(consumer.foo);
  });
}
```

There's also `provideFactories()` that constructs token values from the given factory functions and handles dependencies between the factories.

## How it works

To make `provide()` arguments available in `inject()`, this package uses [zones](https://api.dartlang.org/stable/dart-async/Zone-class.html).
That means it can avoid global mutable state and the edge cases that typically come with it.
For a longer explanation, I wrote a blog post about it [here]().
