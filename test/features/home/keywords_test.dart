import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/features/home/keywords.dart';

void main() {
  group('parseCustomKeywords', () {
    test('splits on half-width commas', () {
      expect(parseCustomKeywords('coffee, street art,bookshops'), [
        'coffee',
        'street art',
        'bookshops',
      ]);
    });

    test('splits on the separators a Chinese keyboard produces', () {
      expect(parseCustomKeywords('本地美食、街头艺术，建筑；书店'), [
        '本地美食',
        '街头艺术',
        '建筑',
        '书店',
      ]);
    });

    test('drops empty entries and surrounding whitespace', () {
      expect(parseCustomKeywords(' , 咖啡 ,, \n 夜景 '), ['咖啡', '夜景']);
      expect(parseCustomKeywords(''), isEmpty);
      expect(parseCustomKeywords('   '), isEmpty);
    });
  });
}
