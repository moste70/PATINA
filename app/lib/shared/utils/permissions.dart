import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestPhotos() async {
    final status = await Permission.photos.request();
    if (status.isGranted) return true;
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  static Future<bool> requestCameraAndPhotos() async {
    final results = await [
      Permission.camera,
      Permission.photos,
    ].request();
    return results[Permission.camera]!.isGranted &&
        (results[Permission.photos]!.isGranted ||
            (await Permission.storage.request()).isGranted);
  }

  static Future<bool> isCameraGranted() async =>
      await Permission.camera.isGranted;

  static Future<bool> isPhotosGranted() async {
    if (await Permission.photos.isGranted) return true;
    return await Permission.storage.isGranted;
  }

  static Future<void> openSettings() async => openAppSettings();
}
