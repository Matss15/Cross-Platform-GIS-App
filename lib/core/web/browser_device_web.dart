import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

enum BrowserDevice { android, ios, other }

/// The kind of device the browser runs on.
///
/// iPads on iPadOS 13+ report a Mac user agent, so a "Mac" with a touch
/// screen is treated as iOS.
BrowserDevice detectBrowserDevice() {
  final navigator = web.window.navigator;
  final agent = navigator.userAgent.toLowerCase();
  if (agent.contains('android')) return BrowserDevice.android;
  if (agent.contains('iphone') ||
      agent.contains('ipad') ||
      agent.contains('ipod')) {
    return BrowserDevice.ios;
  }
  if (agent.contains('macintosh') && navigator.maxTouchPoints > 1) {
    return BrowserDevice.ios;
  }
  return BrowserDevice.other;
}

/// Whether the web app was opened from a home screen icon.
bool isRunningAsHomeScreenApp() {
  if (web.window.matchMedia('(display-mode: standalone)').matches) {
    return true;
  }
  // Older iOS Safari only exposes the non-standard navigator.standalone.
  final standalone = (web.window.navigator as JSObject)['standalone'];
  return standalone.isA<JSBoolean>() && (standalone as JSBoolean).toDart;
}
