enum BrowserDevice { android, ios, other }

/// The kind of device the browser runs on.
BrowserDevice detectBrowserDevice() => BrowserDevice.other;

/// Whether the web app was opened from a home screen icon.
bool isRunningAsHomeScreenApp() => false;
