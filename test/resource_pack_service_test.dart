import 'dart:convert';

import 'package:animpro/services/resource_pack_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _digest() => List<String>.filled(64, 'a').join();

Map<String, dynamic> _entry({
  String id = 'sky-pack',
  String path = 'files/sky-pack.json',
  String? sha256,
  int sizeBytes = 2048,
  int templateCount = 3,
}) =>
    <String, dynamic>{
      'id': id,
      'title': 'Ceus e clima',
      'description': 'Cenarios de dia e noite.',
      'category': 'Ceus',
      'tags': <String>['ceu', 'nuvens'],
      'path': path,
      'sizeBytes': sizeBytes,
      'sha256': sha256 ?? _digest(),
      'templateCount': templateCount,
    };

String _catalog(List<Map<String, dynamic>> packs) => jsonEncode(
      <String, dynamic>{
        'schemaVersion': 1,
        'updatedAt': '2026-11-26',
        'packs': packs,
      },
    );

void main() {
  group('ResourcePackService.parseCatalogJson', () {
    test('parses online pack metadata and calculates a readable size', () {
      final packs = ResourcePackService.parseCatalogJson(
        _catalog(<Map<String, dynamic>>[_entry()]),
      );

      expect(packs, hasLength(1));
      expect(packs.single.id, 'sky-pack');
      expect(packs.single.title, 'Ceus e clima');
      expect(packs.single.category, 'Ceus');
      expect(packs.single.tags, containsAll(<String>['ceu', 'nuvens']));
      expect(packs.single.sizeBytes, 2048);
      expect(packs.single.sizeLabel, '~2 KB');
      expect(packs.single.templateCount, 3);
    });

    test('rejects traversal paths before a download can be attempted', () {
      expect(
        () => ResourcePackService.parseCatalogJson(
          _catalog(<Map<String, dynamic>>[
            _entry(path: '../private/sky-pack.json'),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('rejects a malformed SHA-256 digest', () {
      expect(
        () => ResourcePackService.parseCatalogJson(
          _catalog(<Map<String, dynamic>>[
            _entry(sha256: 'not-a-checksum'),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate pack IDs', () {
      expect(
        () => ResourcePackService.parseCatalogJson(
          _catalog(<Map<String, dynamic>>[
            _entry(),
            _entry(path: 'files/duplicate.json'),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('rejects implausible pack size or template count', () {
      expect(
        () => ResourcePackService.parseCatalogJson(
          _catalog(<Map<String, dynamic>>[
            _entry(sizeBytes: 0),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => ResourcePackService.parseCatalogJson(
          _catalog(<Map<String, dynamic>>[
            _entry(templateCount: 31),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('rejects unsupported catalogue schema versions', () {
      expect(
        () => ResourcePackService.parseCatalogJson(
          jsonEncode(<String, dynamic>{
            'schemaVersion': 2,
            'packs': <dynamic>[],
          }),
        ),
        throwsFormatException,
      );
    });
  });
}
