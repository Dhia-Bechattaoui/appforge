import 'dart:io';

/// Reads a local `.env` file from the filesystem on platforms supporting `dart:io`.
Future<String?> readLocalEnvFile(String fileName) async {
  try {
    final file = File(fileName);
    if (file.existsSync()) {
      return await file.readAsString();
    }
  } catch (_) {
    // Fallback file read is optional when AssetBundle failed.
  }
  return null;
}
