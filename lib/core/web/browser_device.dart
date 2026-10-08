// Tells which kind of device the web app is running on, so the login page
// can offer the Android APK or iOS "Add to Home Screen" steps. Other
// platforms get the stub, which reports [BrowserDevice.other].
export 'browser_device_stub.dart'
    if (dart.library.js_interop) 'browser_device_web.dart';
