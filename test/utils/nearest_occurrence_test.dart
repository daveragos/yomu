import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/utils/epub_text_match.dart';

void main() {
  const text = 'i said yes. i said yes again.';
  const selected = 'i said yes';

  test('a forward drag ends on the selection: its own occurrence wins', () {
    // The menu points at the mouse release, the end of the first match,
    // which is closer to the second match's start than to its own.
    expect(nearestOccurrence(text, selected, 10), 0);
    expect(nearestOccurrence(text, selected, 22), 1);
  });

  test('a backward drag ends on the selection start', () {
    expect(nearestOccurrence(text, selected, 0), 0);
    expect(nearestOccurrence(text, selected, 12), 1);
  });

  test('a point inside or between occurrences picks the nearest one', () {
    expect(nearestOccurrence(text, selected, 4), 0);
    expect(nearestOccurrence(text, selected, 16), 1);
    expect(nearestOccurrence(text, selected, 28), 1);
  });

  test('no match or an empty selection is the first occurrence', () {
    expect(nearestOccurrence(text, 'missing', 3), 0);
    expect(nearestOccurrence(text, '', 3), 0);
  });
}
