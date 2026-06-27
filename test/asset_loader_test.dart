// Tests for the asset loader plumbing. Only the Dart VM path
// (IoAssetLoader) is exercised here; the Flutter path
// (FlutterAssetLoader) needs `flutter test` and a live asset bundle
// to run, and is covered by a separate
// `test_driver/asset_loader_flutter_test.dart` harness.

import 'dart:io';
import 'dart:typed_data';

import 'package:snownlp/src/config.dart';
import 'package:snownlp/src/utils/asset_loader.dart';
import 'package:snownlp/src/utils/asset_loader_io.dart';
import 'package:snownlp/src/utils/binary_format.dart';
import 'package:test/test.dart';

void main() {
  group('IoAssetLoader', () {
    test('resolves seg.bin from package source on disk', () async {
      final bytes = await IoAssetLoader().loadBytes('seg.bin');
      // Should be at least the 16-byte header.
      expect(bytes.length, greaterThanOrEqualTo(16));
      // Magic bytes are 'SNOWnlp\0'.
      expect(bytes[0], 0x53); // 'S'
      expect(bytes[1], 0x4E); // 'N'
      expect(bytes[6], 0x70); // 'p'
      expect(bytes[7], 0x00);
    });

    test('payload decodes through readPayloadFromBytes with matching type',
        () async {
      final bytes = await IoAssetLoader().loadBytes('seg.bin');
      final gz = BinaryFormat.readPayloadFromBytes(
        bytes,
        BinaryFormat.typeSeg,
        source: 'seg.bin',
      );
      // gzip stream must decompress to a non-empty payload.
      final inflated = Uint8List.fromList(GZipCodec().decode(gz));
      expect(inflated.length, greaterThan(0));
    });

    test('reports missing files with a clear StateError', () async {
      expect(
        () => IoAssetLoader().loadBytes('__no_such_model__.bin'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('__no_such_model__.bin'),
          ),
        ),
      );
    });

    test('reports a bad package prefix as a resolution failure', () async {
      // Use a bogus packageName that won't be found while walking up the
      // directory tree, so neither the package: URI path nor the
      // Platform.script path-based fallback can find anything.
      final loader = IoAssetLoader(
        packagePrefix: 'package:no_such_pkg/',
        packageName: 'no_such_pkg',
      );
      expect(
        () => loader.loadBytes('seg.bin'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('package:no_such_pkg/'),
          ),
        ),
      );
    });
  });

  group('SnowConfig.loadModelBytes', () {
    test('routes through the configured loader (default = IoAssetLoader)',
        () async {
      // Ensure we have a clean default, in case a previous test swapped it.
      SnowConfig.instance.assetLoader = IoAssetLoader();
      final bytes = await SnowConfig.instance.loadModelBytes('seg.bin');
      expect(bytes.length, greaterThanOrEqualTo(16));
    });

    test('pluggable: honours a custom in-memory loader', () async {
      // Capture the original loader so we can restore it afterwards.
      final original = SnowConfig.instance.assetLoader;
      addTearDown(() => SnowConfig.instance.assetLoader = original);

      final fakeBytes = BinaryFormat.writeFile(
        BinaryFormat.typeSeg,
        Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD]),
      );
      SnowConfig.instance.assetLoader = _InMemoryLoader({'seg.bin': fakeBytes});

      final bytes = await SnowConfig.instance.loadModelBytes('seg.bin');
      expect(bytes, fakeBytes);
    });
  });
}

class _InMemoryLoader implements AssetLoader {
  _InMemoryLoader(this._store);

  final Map<String, Uint8List> _store;

  @override
  Future<Uint8List> loadBytes(String name) async {
    final bytes = _store[name];
    if (bytes == null) {
      throw StateError('_InMemoryLoader: no bytes registered for "$name"');
    }
    return bytes;
  }
}
