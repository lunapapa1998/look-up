import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/api/species_api.dart';
import 'package:lookup/models/species.dart';

void main() {
  group('SpeciesInfo.fromJson', () {
    test('parses a fully-populated example map', () {
      final info = SpeciesInfo.fromJson({
        'nameKo': '저어새',
        'nameSci': 'Platalea minor',
        'summary': '저어새는 저어새과에 속하는 대형 섭금류이다.',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'wikiUrl': 'https://ko.wikipedia.org/wiki/저어새',
        'source': 'ko.wikipedia',
      });

      expect(info.nameKo, '저어새');
      expect(info.nameSci, 'Platalea minor');
      expect(info.summary, '저어새는 저어새과에 속하는 대형 섭금류이다.');
      expect(info.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(info.wikiUrl, 'https://ko.wikipedia.org/wiki/저어새');
      expect(info.source, 'ko.wikipedia');
    });

    test('parses a not-found-shaped example map', () {
      final info = SpeciesInfo.fromJson({
        'nameKo': null,
        'nameSci': null,
        'summary': null,
        'thumbnailUrl': null,
        'wikiUrl': null,
        'source': 'none',
      });

      expect(info.nameKo, isNull);
      expect(info.nameSci, isNull);
      expect(info.summary, isNull);
      expect(info.thumbnailUrl, isNull);
      expect(info.wikiUrl, isNull);
      expect(info.source, 'none');
    });
  });

  group('FakeSpeciesApi', () {
    test('shouldThrow true throws SpeciesApiException', () {
      final api = FakeSpeciesApi(shouldThrow: true);

      expect(
        () => api.fetchSpecies(sci: 'Platalea minor'),
        throwsA(isA<SpeciesApiException>()),
      );
    });

    test('response left null echoes sci/ko args back with source none', () async {
      final api = FakeSpeciesApi();

      final info = await api.fetchSpecies(sci: 'Platalea minor', ko: '저어새');

      expect(info.nameSci, 'Platalea minor');
      expect(info.nameKo, '저어새');
      expect(info.summary, isNull);
      expect(info.thumbnailUrl, isNull);
      expect(info.wikiUrl, isNull);
      expect(info.source, 'none');
    });
  });
}
