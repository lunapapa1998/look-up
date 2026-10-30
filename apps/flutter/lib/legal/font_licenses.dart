import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers the bundled fonts' SIL OFL 1.1 texts with Flutter's standard
/// [LicenseRegistry] (shown by `showLicensePage`/`LicensePage` if ever used).
/// Call once at startup.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const <String>['Bithumb Gothic'],
      await rootBundle.loadString('assets/fonts/OFL-BithumbGothic.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const <String>['Pretendard'],
      await rootBundle.loadString('assets/fonts/OFL.txt'),
    );
  });
}
