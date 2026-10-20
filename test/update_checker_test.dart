import 'package:flutter_test/flutter_test.dart';
import 'package:pow2/update_checker.dart';

void main() {
  group('UpdateChecker.isNewer', () {
    test('a newer patch version is newer', () {
      expect(UpdateChecker.isNewer('1.0.1', '1.0.0'), isTrue);
    });

    test('a newer minor version beats a higher older patch', () {
      expect(UpdateChecker.isNewer('1.1.0', '1.0.9'), isTrue);
    });

    test('a newer major version is newer', () {
      expect(UpdateChecker.isNewer('2.0.0', '1.9.9'), isTrue);
    });

    test('the same version is not newer, build number is ignored', () {
      expect(UpdateChecker.isNewer('1.0.0', '1.0.0+1'), isFalse);
    });

    test('an older version is not newer', () {
      expect(UpdateChecker.isNewer('0.9.0', '1.0.0'), isFalse);
    });
  });
}
