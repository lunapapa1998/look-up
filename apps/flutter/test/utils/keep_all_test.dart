import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/utils/keep_all.dart';

void main() {
  test('joins characters inside each word with U+2060, keeps spaces', () {
    expect(keepAll('좋은 날'), '좋⁠은 날');
    expect(keepAll('가'), '가');
    expect(keepAll(''), '');
    expect(keepAll('a b'), 'a b');
    const s = '오늘은 하늘을 보기 좋은 날이에요.';
    expect(keepAll(s).replaceAll(kWordJoiner, ''), s);
    expect(keepAll(s).split(' ').length, s.split(' ').length);
  });

  testWidgets('wrapped lines break only at spaces', (tester) async {
    const s = '갯벌을 찾은 새부터 밤하늘의 별까지, 오늘의 관찰을 시작해 보세요.';
    final joined = keepAll(s);
    for (final maxWidth in const [120.0, 180.0, 260.0]) {
      final painter = TextPainter(
        text: TextSpan(text: joined, style: const TextStyle(fontSize: 15)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      var offset = 0;
      while (offset < joined.length) {
        final line = painter.getLineBoundary(TextPosition(offset: offset));
        if (line.end >= joined.length) break;
        final atSpace =
            joined[line.end] == ' ' ||
            (line.end > 0 && joined[line.end - 1] == ' ');
        expect(atSpace, isTrue, reason: 'mid-word break at $maxWidth px');
        offset = line.end + 1;
      }
      painter.dispose();
    }
  });
}
