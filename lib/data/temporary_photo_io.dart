import 'dart:io';

// Only call this for a path returned by CameraController.takePicture().
Future<void> deleteTemporaryPhoto(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // A device cleanup failure must not discard a photo already read into memory.
  }
}
