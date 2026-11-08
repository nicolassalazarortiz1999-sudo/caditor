import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/project.dart';

const _videoExt = {'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp'};

bool isVideoPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot == -1) return false;
  return _videoExt.contains(path.substring(dot + 1).toLowerCase());
}

class ProjectStorage {
  static Future<Directory> _root() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/caditor');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copia un archivo elegido de la galería a la carpeta privada de la app,
  /// para que el proyecto siga funcionando aunque el archivo temporal se borre.
  static Future<String> importMedia(String sourcePath) async {
    final root = await _root();
    final dir = Directory('${root.path}/media');
    if (!await dir.exists()) await dir.create(recursive: true);
    final name = sourcePath.split('/').last;
    final dest = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$name';
    await File(sourcePath).copy(dest);
    return dest;
  }

  static Future<File> _file() async =>
      File('${(await _root()).path}/project.json');

  static Future<void> save(Project p) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(p.toJson()));
  }

  static Future<Project?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return Project.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> exists() async {
    try {
      return await (await _file()).exists();
    } catch (_) {
      return false;
    }
  }
}
