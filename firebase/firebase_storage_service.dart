import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload file
  Future<String> uploadFile({
    required File file,
    required String path,
    String? userId,
  }) async {
    try {
      final fileName = path.basename(file.path);
      final storagePath = userId != null 
          ? '$path/$userId/$fileName'
          : '$path/$fileName';
      
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(file);
      
      final snapshot = await uploadTask;
      final downloadURL = await snapshot.ref.getDownloadURL();
      
      return downloadURL;
    } on FirebaseException catch (e) {
      throw 'Error uploading file: ${e.message}';
    }
  }

  // Upload image with compression
  Future<String> uploadImage({
    required File imageFile,
    required String path,
    String? userId,
    int maxWidth = 1920,
    int maxHeight = 1920,
    int quality = 85,
  }) async {
    // Note: Image compression requires image package
    // import 'package:image/image.dart' as img;
    
    try {
      // Read and compress image
      // final bytes = await imageFile.readAsBytes();
      // final image = img.decodeImage(bytes);
      // final compressed = img.copyResize(image!, width: maxWidth, height: maxHeight);
      // final compressedBytes = img.encodeJpg(compressed, quality: quality);
      // final tempFile = File('${imageFile.path}_compressed.jpg');
      // await tempFile.writeAsBytes(compressedBytes);
      
      // Upload compressed file
      return await uploadFile(
        file: imageFile, // Use tempFile if compression is implemented
        path: path,
        userId: userId,
      );
    } catch (e) {
      throw 'Error uploading image: $e';
    }
  }

  // Delete file
  Future<void> deleteFile(String filePath) async {
    try {
      final ref = _storage.ref().child(filePath);
      await ref.delete();
    } on FirebaseException catch (e) {
      throw 'Error deleting file: ${e.message}';
    }
  }

  // Get download URL
  Future<String> getDownloadURL(String filePath) async {
    try {
      final ref = _storage.ref().child(filePath);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw 'Error getting download URL: ${e.message}';
    }
  }

  // List files in a path
  Future<List<String>> listFiles(String path) async {
    try {
      final ref = _storage.ref().child(path);
      final result = await ref.listAll();
      
      return result.items.map((item) => item.fullPath).toList();
    } on FirebaseException catch (e) {
      throw 'Error listing files: ${e.message}';
    }
  }
}
