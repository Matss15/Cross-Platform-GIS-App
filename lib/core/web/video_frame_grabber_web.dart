import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

web.HTMLCanvasElement? _canvas;

/// Returns a grayscale frame of the live camera video, [width] pixels wide,
/// or null when no playing video is available.
///
/// Drawing the video into a tiny canvas is far cheaper than takePicture,
/// which encodes and then decodes a full-resolution JPEG for every frame.
(int, int, Uint8List)? grabVideoGrayFrame(int width) {
  final videos = web.document.querySelectorAll('video');
  web.HTMLVideoElement? video;
  for (var i = videos.length - 1; i >= 0; i--) {
    final node = videos.item(i);
    if (node == null || !node.isA<web.HTMLVideoElement>()) continue;
    final candidate = node as web.HTMLVideoElement;
    if (candidate.videoWidth > 0 && candidate.readyState >= 2) {
      video = candidate;
      break;
    }
  }
  if (video == null) return null;

  final outWidth = width < video.videoWidth ? width : video.videoWidth;
  final outHeight = (video.videoHeight * outWidth / video.videoWidth).floor();
  if (outHeight <= 0) return null;
  final canvas = _canvas ??= web.HTMLCanvasElement();
  if (canvas.width != outWidth) canvas.width = outWidth;
  if (canvas.height != outHeight) canvas.height = outHeight;
  final context =
      canvas.getContext('2d', {'willReadFrequently': true}.jsify())
          as web.CanvasRenderingContext2D;
  context.drawImage(video, 0, 0, outWidth.toDouble(), outHeight.toDouble());
  final rgba = context.getImageData(0, 0, outWidth, outHeight).data.toDart;

  final gray = Uint8List(outWidth * outHeight);
  for (var i = 0, p = 0; i < gray.length; i++, p += 4) {
    gray[i] = (rgba[p] * 77 + rgba[p + 1] * 150 + rgba[p + 2] * 29) >> 8;
  }
  return (outWidth, outHeight, gray);
}
