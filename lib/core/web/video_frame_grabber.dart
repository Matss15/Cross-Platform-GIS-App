// Reads small grayscale frames straight from the camera <video> element on
// web. Other platforms get the stub, which always returns null.
export 'video_frame_grabber_stub.dart'
    if (dart.library.js_interop) 'video_frame_grabber_web.dart';
