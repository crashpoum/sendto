import 'package:flutter_test/flutter_test.dart';
import 'package:sendto/models/peer.dart';

void main() {
  test('device id maps to a stable tile', () {
    const id = 'same-device';
    expect(colorIndexForId(id), colorIndexForId(id));
    expect(colorIndexForId(id), isNot(colorIndexForId('other-device')));
  });
}
