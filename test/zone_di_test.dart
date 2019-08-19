import 'package:test/test.dart';
import 'package:zone_di/src/zone_di.dart';
import 'package:zone_di/zone_di.dart';

final throwsMissingDependencyException =
    TypeMatcher<MissingDependencyException>();

final tokenA = Token<String>('A');

void main() {
  test('inject() from root zone fails', () {
    expect(() => inject(tokenA), throwsMissingDependencyException);
  });
}
