import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Comportement de défilement global de l'application.
///
/// Les postes de travail (web/desktop, écrans 1920×1080) ont besoin de barres
/// de défilement toujours visibles et du défilement à la souris (cliquer-
/// glisser), que Flutter ne fournit pas par défaut sur ces plateformes.
/// Sur mobile, le comportement tactile habituel est conservé.
class AppScrollBehavior extends MaterialScrollBehavior {
  static bool get _isDesktop =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    if (!_isDesktop) {
      return super.buildScrollbar(context, child, details);
    }

    switch (details.direction) {
      case AxisDirection.up:
      case AxisDirection.down:
        return Scrollbar(
          controller: details.controller,
          thumbVisibility: true,
          child: child,
        );
      case AxisDirection.left:
      case AxisDirection.right:
        return child;
    }
  }
}
