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

    test('parses summaryLong and a fully-populated conservation map', () {
      final info = SpeciesInfo.fromJson({
        'nameKo': '저어새',
        'nameSci': 'Platalea minor',
        'summary': '저어새는 저어새과에 속하는 대형 섭금류이다.',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'wikiUrl': 'https://ko.wikipedia.org/wiki/저어새',
        'source': 'ko.wikipedia',
        'summaryLong':
            '저어새는 저어새과에 속하는 대형 섭금류로, 부리가 주걱 모양으로 넓적한 것이 특징이다.',
        'conservation': {
          'naturalMonument': '천연기념물 제205-1호',
          'koreaEndangered': '멸종위기 I급',
          'iucn': 'EN',
        },
      });

      expect(
        info.summaryLong,
        '저어새는 저어새과에 속하는 대형 섭금류로, 부리가 주걱 모양으로 넓적한 것이 특징이다.',
      );
      expect(info.conservation, isNotNull);
      expect(info.conservation!.naturalMonument, '천연기념물 제205-1호');
      expect(info.conservation!.koreaEndangered, '멸종위기 I급');
      expect(info.conservation!.iucn, 'EN');
    });

    test(
      'treats a conservation map with all-null sub-fields as null',
      () {
        final info = SpeciesInfo.fromJson({
          'nameKo': '저어새',
          'nameSci': 'Platalea minor',
          'summary': '저어새는 저어새과에 속하는 대형 섭금류이다.',
          'thumbnailUrl': 'https://example.com/thumb.jpg',
          'wikiUrl': 'https://ko.wikipedia.org/wiki/저어새',
          'source': 'ko.wikipedia',
          'summaryLong':
              '저어새는 저어새과에 속하는 대형 섭금류로, 부리가 주걱 모양으로 넓적한 것이 특징이다.',
          'conservation': {
            'naturalMonument': null,
            'koreaEndangered': null,
            'iucn': null,
          },
        });

        expect(info.conservation, isNull);
      },
    );

    test(
      'parses a pre-023-shaped map omitting summaryLong/conservation as null '
      'for both (backward compatibility)',
      () {
        final info = SpeciesInfo.fromJson({
          'nameKo': '저어새',
          'nameSci': 'Platalea minor',
          'summary': '저어새는 저어새과에 속하는 대형 섭금류이다.',
          'thumbnailUrl': 'https://example.com/thumb.jpg',
          'wikiUrl': 'https://ko.wikipedia.org/wiki/저어새',
          'source': 'ko.wikipedia',
        });

        expect(info.summaryLong, isNull);
        expect(info.conservation, isNull);
      },
    );
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
