import 'package:test/test.dart';
import 'package:zone_di2/zone_di2.dart';

final throwsMissingDependencyException =
    throwsA(TypeMatcher<MissingDependencyException>());

final tokenS1 = Token<String>('S1');
final tokenS2 = Token<String>('S2');
final tokenStrWithDefault =
    Token.withDefault('StrWithDefault', 'StrWithDefault default value');
final tokenNullStrWithDefault =
    Token<String?>.withDefault('NullStrWithDefault', null);

final tokenA = Token<A>('A');
final tokenANull = Token<A?>('A?');
final tokenB = Token<B>('B');
final tokenC = Token<C>('C');
final tokenD = Token<D>('D');
final tokenE = Token<E>('E');
final tokenF = Token<F>('F');
final tokenG = Token<G>('G');
final tokenGNull = Token<G?>('G?');

class A {
  A(this.value);
  final String value;
}

class B {
  B()
      : a = inject(tokenA),
        c = inject(tokenC);
  final A? a;
  final C? c;
}

class C {
  C() : a = inject(tokenA);
  final A? a;
}

class D {
  D() : e = inject(tokenE);

  final E? e;
}

class E {
  E() : f = inject(tokenF);
  final F? f;
}

class F {
  F()
      : c = inject(tokenC),
        g = inject(tokenG);
  final C? c;
  final G? g;
}

class G {
  G() : e = inject(tokenE);
  final E? e;
}

class H {
  H() : g = inject(tokenGNull);
  final G? g;
}

void main() {
  group('inject()', () {
    test('outside of provide() fails', () {
      expect(() => inject(tokenS1), throwsMissingDependencyException);
    });

    test('with not-provided token fails', () {
      provideSingle(tokenS2, 'value S2', () {
        expect(() => inject(tokenS1), throwsMissingDependencyException);
      });
    });

    test('with not-provided token uses default value if available', () {
      expect(inject(tokenStrWithDefault), 'StrWithDefault default value');
      expect(inject(tokenNullStrWithDefault), isNull);
      expect(inject(tokenNullStrWithDefault), isNull);
    });

    test('prefers provided to default value', () {
      provideSingle(tokenStrWithDefault, 'provided', () {
        provideSingle(tokenS1, 'S1 value', () {
          expect(inject(tokenStrWithDefault), 'provided');
        });
      });

      provideSingle(tokenStrWithDefault, null, () {
        expect(inject(tokenStrWithDefault), isNull);
        expect(() => inject(tokenStrWithDefault),
            throwsMissingDependencyException);
      });
    });

    test('prefers innermost provided value', () {
      provide({tokenS1: 'outer'}, () {
        provide({tokenS1: 'inner'}, () {
          expect(inject(tokenS1), 'inner');
        });
      });
    });
  });

  group('provide()', () {
    test('throws a CastError if token/value types are not compatible', () {
      expect(() => provide({tokenS1: 1}, () {}),
          throwsA(TypeMatcher<TypeError>()));
    });
  });

  group('provideFactories()', () {
    test('calls all factories in own zone', () {
      final outerA = A('outer');
      final innerA = A('inner');

      B factoryB() => provideSingle(tokenA, innerA, () => B());
      C factoryC() => C();

      provideSingle(tokenA, outerA, () {
        provideFactories({tokenB: factoryB, tokenC: factoryC}, () {
          final a = inject(tokenA);
          final b = inject(tokenB);
          final c = inject(tokenC);

          expect(a, outerA);
          expect(b.a, innerA);
          expect(b.c, c);
          expect(c.a, outerA);
        });
      });
    });

    test('detects circular dependencies', () {
      try {
        provideFactories({
          tokenA: () => A('value'),
          tokenC: () => C(),
          tokenD: () => D(),
          tokenE: () => E(),
          tokenF: () => F(),
          tokenG: () => G()
        }, () {});
        fail('should have thrown CircularDependencyException');
      } on CircularDependencyException catch (e) {
        expect(e.tokens, [tokenE, tokenF, tokenG]);
      }

      try {
        provideFactories(
          {tokenS1: () => inject(tokenS1)},
          () {},
        );
        fail('should have thrown CircularDependencyException');
      } on CircularDependencyException catch (e) {
        expect(e.tokens, [tokenS1]);
      }
    });

    test('handles null values', () {
      provideFactories({tokenANull: () => null, tokenC: () => C()}, () {
        expect(inject(tokenANull), isNull);
        expect(inject(tokenC).a, isNull);
      });
    });
  });
}
