/// Minimal compile-time stub for `dart:io` filesystem types on non-IO targets
/// (such as Flutter Web). Methods throw [UnsupportedError] if invoked at runtime.
abstract class FileSystemEntity {
  String get path;
  Uri get uri => Uri.file(path);
  bool existsSync();
}

class Directory extends FileSystemEntity {
  @override
  final String path;

  Directory(this.path);

  @override
  bool existsSync() => false;

  void createSync({bool recursive = false}) =>
      _unsupported('Directory.createSync');

  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) =>
      _unsupported('Directory.listSync');

  void deleteSync({bool recursive = false}) =>
      _unsupported('Directory.deleteSync');
}

class File extends FileSystemEntity {
  @override
  final String path;

  File(this.path);

  Directory get parent => Directory('');

  @override
  bool existsSync() => false;

  String readAsStringSync() => _unsupported('File.readAsStringSync');

  List<String> readAsLinesSync() => _unsupported('File.readAsLinesSync');

  void writeAsStringSync(String contents) =>
      _unsupported('File.writeAsStringSync');

  File copySync(String newPath) => _unsupported('File.copySync');

  File renameSync(String newPath) => _unsupported('File.renameSync');

  void deleteSync({bool recursive = false}) => _unsupported('File.deleteSync');
}

Never _unsupported(String op) {
  throw UnsupportedError(
    '$op requires dart:io and is not supported on Flutter Web.',
  );
}
