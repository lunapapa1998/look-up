import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/legal/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registerFontLicenses adds Bithumb Gothic and Pretendard OFL', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();

    LicenseEntry entryFor(String package) =>
        entries.firstWhere((e) => e.packages.contains(package));

    final bithumb = entryFor('Bithumb Gothic');
    final pretendard = entryFor('Pretendard');
    String text(LicenseEntry e) => e.paragraphs.map((p) => p.text).join('\n');
    expect(text(bithumb), contains('SIL OPEN FONT LICENSE'));
    expect(text(pretendard), contains('SIL OPEN FONT LICENSE'));
  });
}
