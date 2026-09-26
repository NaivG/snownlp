/// Flutter bootstrap for `package:snownlp`.
///
/// Importing this file (once, in your app's `main`) switches the
/// default asset loader from [IoAssetLoader] to [FlutterAssetLoader],
/// so every model file is read from the Flutter asset bundle instead of
/// the local file system.
///
/// ```dart
/// import 'package:snownlp/snownlp_flutter.dart';
///
/// void main() {
///   useFlutterAssetLoader();
///   runApp(const MyApp());
/// }
/// ```
///
/// The `lib/src/data/*.bin` files are bundled automatically because
/// the snownlp package declares them in its own `flutter.assets`
/// block, so no further pubspec changes are required in the consuming
/// app.
library;

import 'src/config.dart';
import 'src/utils/asset_loader_flutter.dart';

export 'src/utils/asset_loader_flutter.dart' show FlutterAssetLoader;

/// Register [FlutterAssetLoader] as the active [SnowConfig.assetLoader].
///
/// Call this once at app startup, before any model is touched. After
/// that, all `await SnowNLP(...)`, `await seg(...)`, `await tag(...)`,
/// `await zh2hans(...)`, `await getPinyin(...)` calls read from the
/// Flutter asset bundle with the key
/// `packages/snownlp/lib/src/data/$name`.
void useFlutterAssetLoader() {
  SnowConfig.instance.assetLoader = FlutterAssetLoader();
}
