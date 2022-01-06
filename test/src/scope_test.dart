import 'dart:convert';
import 'dart:math';

import 'package:scope/scope.dart';

import 'package:test/test.dart';

final throwsMissingDependencyException =
    throwsA(const TypeMatcher<MissingDependencyException<dynamic>>());

final keyS1 = ScopeKey<String>('S1');
final keyS2 = ScopeKey<String>('S2');
final keyStrWithDefault = ScopeKey<String?>.withDefault(
    'StrWithDefault default value', 'StrWithDefault');
final keyNullStrWithDefault =
    ScopeKey<String?>.withDefault(null, 'NullStrWithDefault');

final keyA = ScopeKey<A>('A');
final keyANull = ScopeKey<A?>('A?');
final keyB = ScopeKey<B>('B');
final keyC = ScopeKey<C>('C');
final keyD = ScopeKey<D>('D');
final keyE = ScopeKey<E>('E');
final keyF = ScopeKey<F>('F');
final keyG = ScopeKey<G>('G');
final keyGNull = ScopeKey<G?>('G?');
final keyI = ScopeKey<I>('I');

void main() {
  test('scope ...', () {
    final keyAge = ScopeKey<int>('an int');
    final keyName = ScopeKey<String>('a String');
    final keyRandom = ScopeKey<String>('Random Factory');

    Scope()
      ..value<int>(keyAge, 10)
      ..value<String>(keyName, 'Help me')
      ..factory<String>(keyRandom, () => getRandString(5))
      ..run(() {
        print('Age: ${use(keyAge)} Name: ${use(keyName)} '
            'Random Factory: ${use(keyRandom)}');
      });
  });

  group('async calls', () {
    test('scope ...', () async {
      final keyAge = ScopeKey<int>('age');

      final scope = Scope()..value<int>(keyAge, 18);

      final one = await scope.run<Future<int>>(() async {
        final delayedvalue =
            Future<int>.delayed(const Duration(seconds: 1), () => use(keyAge));

        return delayedvalue;
      });

      expect(one, equals(18));
    });
  });

  group('existance', () {
    test('withinScope', () {
      Scope().run(() {
        expect(isWithinScope(), isTrue);
      });
    });
    test('not withinScope', () {
      expect(isWithinScope(), isFalse);
    });

    test('hasScopeKey', () {
      Scope()
        ..value<A>(keyA, A('A'))
        ..run(() {
          expect(hasScopeKey<A>(keyA), isTrue);
        });
    });
    test('not hasScopeKey', () {
      expect(hasScopeKey<A>(keyA), isFalse);
    });
  });
  group('inject()', () {
    test('outside of provide() fails', () {
      expect(() => use(keyS1), throwsMissingDependencyException);
    });

    test('with not-provided key fails', () {
      Scope()
        ..value<String>(keyS2, 'value S2')
        ..run(() {
          expect(() => use(keyS1), throwsMissingDependencyException);
        });
    });

    test('with not-provided key uses default value if available', () {
      expect(
        use(keyStrWithDefault),
        'StrWithDefault default value',
      );
      expect(use(keyNullStrWithDefault), isNull);
      expect(use(keyNullStrWithDefault), isNull);
    });

    test('prefers provided to default value', () {
      Scope()
        ..value<String?>(keyStrWithDefault, 'provided')
        ..value<String>(keyS1, 'S1 value')
        ..run(() {
          expect(use(keyStrWithDefault), 'provided');
        });
    });

    test('Test String?', () {
      Scope()
        ..value<String?>(keyStrWithDefault, null)
        ..run(() {
          expect(use(keyStrWithDefault), isNull);
        });
    });
  });

  test('prefers innermost provided value', () {
    Scope()
      ..value<String>(keyS1, 'outer')
      ..run(() {
        Scope()
          ..value(keyS1, 'inner')
          ..run(() {
            expect(use(keyS1), 'inner');
          });
      });
  });

  group('provide()', () {
    test('throws a CastError if key/value types are not compatible', () {
      expect(
          () => Scope()
            ..value(keyS1, 1)
            ..run(() {}),
          throwsA(const TypeMatcher<TypeError>()));
    });
  });

  group('return values', () {
    test('return an int', () {
      final ageKey = ScopeKey<int>();
      final scope = Scope()..value<int>(ageKey, 18);
      final age = scope.run<int>(() => use(ageKey));

      expect(age, equals(18));
    });
  });
  group('Scope.factory()', () {
    test('calls all factories in own zone', () {
      final outerA = A('outer');
      final innerA = A('inner');
      final outerI = I('outer');

      // final scopeB = Scope()..value<B>(keyB, innerB);
      // B factoryB() => scopeB.run(() => B());
      // C factoryC() => C();

      Scope()
        ..value(keyANull, outerA)
        ..value(keyI, outerI)
        ..factory<B>(keyB, () => B())
        ..run(() {
          Scope()
            ..factory<A>(keyA, () => innerA)
            ..factory<C>(keyC, () => C())
            ..run(() {
              final a = use(keyA);
              expect(a, innerA);

              final b = use(keyB);
              expect(b.a, null);
              expect(b.c, null);

              final c = use(keyC);
              expect(c.a, outerA);

              final i = use(keyI);
              expect(i, equals(outerI));
            });
        });
    });

    test('detects circular dependencies', () {
      try {
        Scope()
          ..factory<A>(keyA, () => A('value'))
          ..factory<C>(keyC, () => C())
          ..factory<D>(keyD, () => D())
          ..factory<E>(keyE, () => E())
          ..factory<F>(keyF, () => F())
          ..factory<G>(keyG, () => G())
          ..run(() {});
        fail('should have thrown CircularDependencyException');
      } on CircularDependencyException<dynamic> catch (e) {
        expect(e.keys, [keyE, keyF, keyG]);
      }

      try {
        Scope()
          ..factory(keyS1, () => use(keyS1))
          ..run(
            () {},
          );
        fail('should have thrown CircularDependencyException');
      } on CircularDependencyException<dynamic> catch (e) {
        expect(e.keys, [keyS1]);
      }
    });

    test('handles null values', () {
      Scope()
        ..factory(keyANull, () => null)
        ..factory(keyC, () => C())
        ..run(() {
          expect(use(keyANull), isNull);
          expect(use(keyC).a, isNull);
        });
    });

    test('duplicate dependencies', () {
      /// can add the same key twice to the same scope.
      expect(
          () => Scope()
            ..value<A>(keyA, A('first'))
            ..value<A>(keyA, A('second')),
          throwsA(isA<DuplicateDependencyException<A>>()));

      expect(
          () => Scope()
            ..factory<A>(keyA, () => A('first'))
            ..factory<A>(keyA, () => A('second')),
          throwsA(isA<DuplicateDependencyException<A>>()));

      /// keys at different leves are not duplicates.
      Scope()
        ..factory<A>(keyA, () => A('first'))
        ..run(() {
          final firstA = use(keyA);
          expect(firstA.value, equals('first'));

          Scope()
            ..factory<A>(keyA, () => A('second'))
            ..run(() {
              final secondA = use(keyA);
              expect(secondA.value, equals('second'));
            });
        });
    });
  });
}

String getRandString(int len) {
  final random = Random.secure();
  final values = List<int>.generate(len, (i) => random.nextInt(255));
  return base64UrlEncode(values);
}

class A {
  A(this.value);
  final String value;
}

class B {
  B()
      : a = use(keyANull),
        c = use(keyC);

  final A? a;
  final C? c;
}

class C {
  C() : a = use(keyANull);
  final A? a;
}

class D {
  D() : e = use(keyE);

  final E? e;
}

class E {
  E() : f = use(keyF);
  final F? f;
}

class F {
  F()
      : c = use(keyC),
        g = use(keyG);
  final C? c;
  final G? g;
}

class G {
  G() : e = use(keyE);
  final E? e;
}

class H {
  H() : g = use(keyGNull);
  final G? g;
}

class I {
  I(this.value);
  final String value;
}
