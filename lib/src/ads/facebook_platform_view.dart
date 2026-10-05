import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A native Facebook banner or native-ad view.
class FacebookPlatformView extends StatelessWidget {
  /// Shows the native view already loaded for [id].
  const FacebookPlatformView({
    super.key,
    required this.viewType,
    required this.id,
  });

  /// Platform view type registered by the plugin.
  final String viewType;

  /// Id returned by the Facebook bridge.
  final String id;

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, String>{'id': id};
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return UiKitView(
      viewType: viewType,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
