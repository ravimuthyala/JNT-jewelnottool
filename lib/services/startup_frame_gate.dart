import 'package:flutter/widgets.dart';

class StartupFrameGate {
  static bool _deferred = false;
  static bool _released = false;

  static void deferFirstFrame() {
    if (_deferred || _released) return;
    WidgetsBinding.instance.deferFirstFrame();
    _deferred = true;
  }

  static void allowFirstFrame() {
    if (!_deferred || _released) return;
    WidgetsBinding.instance.allowFirstFrame();
    _released = true;
  }
}
