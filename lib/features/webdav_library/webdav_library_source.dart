import 'dart:convert';

import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/extensions.dart';
import 'package:venera_next/foundation/res.dart';
import 'package:venera_next/network/app_dio.dart';
import 'package:webdav_client/webdav_client.dart' hide File;

class WebDavLibraryConfig {
  WebDavLibraryConfig({
    required String url,
    required String user,
    required String pass,
    required String remotePath,
  }) : url = url.trim(),
       user = user.trim(),
       pass = pass.trim(),
       remotePath = _normalizedPath(remotePath);

  final String url;
  final String user;
  final String pass;
  final String remotePath;

  bool get isValid => url.isNotEmpty;

  Map<String, String> get authHeaders {
    if (user.isEmpty && pass.isEmpty) return const {};
    final token = base64Encode(utf8.encode('$user:$pass'));
    return {'authorization': 'Basic $token'};
  }

  static WebDavLibraryConfig fromSettings() {
    final config = appdata.settings['webdavComicLibrary'];
    final path = appdata.settings['webdavComicLibraryPath'];
    if (config is List && config.whereType<String>().length == 3) {
      final values = config.whereType<String>().toList();
      return WebDavLibraryConfig(
        url: values[0],
        user: values[1],
        pass: values[2],
        remotePath: path is String ? path : '/venera_comics/',
      );
    }
    return WebDavLibraryConfig(
      url: '',
      user: '',
      pass: '',
      remotePath: path is String ? path : '/venera_comics/',
    );
  }

  static Future<void> saveToSettings(WebDavLibraryConfig config) async {
    if (!config.isValid && config.user.isEmpty && config.pass.isEmpty) {
      appdata.settings['webdavComicLibrary'] = [];
    } else {
      appdata.settings['webdavComicLibrary'] = [
        config.url,
        config.user,
        config.pass,
      ];
    }
    appdata.settings['webdavComicLibraryPath'] = config.remotePath;
    await appdata.saveData(false);
  }

  String childDirectoryPath(String name) {
    return '${_ensureTrailingSlash(remotePath)}${_stripSlashes(name)}/';
  }

  String childFilePath(String parent, String name) {
    return '${_ensureTrailingSlash(parent)}${_stripSlashes(name)}';
  }

  String fileUrl(String remoteFilePath) {
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final path = remoteFilePath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return '$base/$path';
  }

  static String _normalizedPath(String path) {
    var result = path.trim().replaceAll('\\', '/');
    if (result.isEmpty) result = '/venera_comics/';
    if (!result.startsWith('/')) result = '/$result';
    if (!result.endsWith('/')) result = '$result/';
    return result;
  }

  static String _ensureTrailingSlash(String path) {
    return path.endsWith('/') ? path : '$path/';
  }

  static String _stripSlashes(String value) {
    return value.replaceAll(RegExp(r'^/+|/+$'), '');
  }
}

class WebDavLibraryEntry {
  const WebDavLibraryEntry({required this.name, required this.isDirectory});

  final String name;
  final bool isDirectory;
}

abstract class WebDavLibraryOps {
  Future<void> test(WebDavLibraryConfig config);

  Future<List<WebDavLibraryEntry>> readDir(
    WebDavLibraryConfig config,
    String remotePath,
  );
}

class _WebDavLibraryOps implements WebDavLibraryOps {
  Client _client(WebDavLibraryConfig config) {
    return newClient(
      config.url,
      user: config.user,
      password: config.pass,
      adapter: RHttpAdapter(),
    );
  }

  @override
  Future<void> test(WebDavLibraryConfig config) async {
    await _client(config).readDir(config.remotePath);
  }

  @override
  Future<List<WebDavLibraryEntry>> readDir(
    WebDavLibraryConfig config,
    String remotePath,
  ) async {
    final entries = await _client(config).readDir(remotePath);
    return entries
        .where((entry) => entry.name != null)
        .map(
          (entry) => WebDavLibraryEntry(
            name: entry.name!,
            isDirectory: entry.isDir == true,
          ),
        )
        .toList();
  }
}

class WebDavLibrarySource {
  const WebDavLibrarySource._();

  static const sourceKey = 'webdav_library';
  static const explorePageTitle = 'WebDAV Library';
  static const rootChapterId = '__root__';
  static const rootChapterTitle = 'Images';
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'jpe'};
  static const _archiveExtensions = {'cbz', 'zip', '7z', 'cb7'};

  static WebDavLibraryOps ops = _WebDavLibraryOps();

  static void resetOps() {
    ops = _WebDavLibraryOps();
  }

  static ComicSource create() {
    return ComicSource(
      'WebDAV Library',
      sourceKey,
      null,
      null,
      null,
      null,
      [
        ExplorePageData(
          explorePageTitle,
          ExplorePageType.multiPageComicList,
          loadComics,
          null,
          null,
          null,
        ),
      ],
      null,
      null,
      loadComicInfo,
      null,
      loadComicPages,
      getImageLoadingConfig,
      getThumbnailLoadingConfig,
      '',
      '',
      '',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      false,
      false,
      null,
      null,
    );
  }

  static Future<Res<bool>> testConnection(WebDavLibraryConfig config) async {
    if (!config.isValid) {
      return const Res.error('Invalid WebDAV comic library configuration');
    }
    try {
      await ops.test(config);
      return const Res(true);
    } catch (e) {
      return Res.error(e.toString());
    }
  }

  static Future<Res<List<Comic>>> loadComics(int page) async {
    if (page != 1) {
      return const Res([], subData: 1);
    }
    final config = WebDavLibraryConfig.fromSettings();
    if (!config.isValid) {
      return const Res.error('Invalid WebDAV comic library configuration');
    }
    try {
      final entries = await ops.readDir(config, config.remotePath);
      final comics =
          entries
              .where((entry) => entry.isDirectory)
              .where((entry) => !_isIgnoredEntry(entry.name))
              .map(
                (entry) => Comic(
                  entry.name,
                  'cover.jpg',
                  entry.name,
                  null,
                  const ['WebDAV'],
                  '',
                  sourceKey,
                  null,
                  null,
                ),
              )
              .toList()
            ..sort((a, b) => _compareNames(a.title, b.title));
      return Res(comics, subData: 1);
    } catch (e) {
      return Res.error(e.toString());
    }
  }

  static Future<Res<ComicDetails>> loadComicInfo(String id) async {
    final config = WebDavLibraryConfig.fromSettings();
    if (!config.isValid) {
      return const Res.error('Invalid WebDAV comic library configuration');
    }
    try {
      final comicPath = config.childDirectoryPath(id);
      final entries = await ops.readDir(config, comicPath);
      final rootImages = _imageEntries(
        entries,
      ).where((entry) => !_isNamedCover(entry.name)).toList();
      final chapterMap = <String, String>{};
      final cover = _findNamedCover(entries);
      String? coverPath = cover == null
          ? null
          : config.childFilePath(comicPath, cover.name);
      final directories =
          entries
              .where((entry) => entry.isDirectory)
              .where((entry) => !_isIgnoredEntry(entry.name))
              .toList()
            ..sort((a, b) => _compareNames(a.name, b.name));
      for (final directory in directories) {
        final chapterPath = config.childDirectoryPath('$id/${directory.name}');
        final chapterEntries = await ops.readDir(config, chapterPath);
        final files = _imageEntries(
          chapterEntries,
        ).where((entry) => !_isNamedCover(entry.name)).toList();
        if (files.isEmpty) continue;
        chapterMap[directory.name] = directory.name;
        coverPath ??= config.childFilePath(chapterPath, files.first.name);
      }
      if (chapterMap.isEmpty && rootImages.isNotEmpty) {
        chapterMap[rootChapterId] = rootChapterTitle;
        coverPath ??= config.childFilePath(comicPath, rootImages.first.name);
      }
      if (chapterMap.isEmpty) {
        return const Res.error('No images found in the WebDAV comic directory');
      }
      return Res(
        ComicDetails.fromJson({
          'title': id,
          'subtitle': '',
          'cover': coverPath ?? 'cover.jpg',
          'description': '',
          'tags': {
            'Source': ['WebDAV'],
          },
          'chapters':
              chapterMap.length == 1 && chapterMap.containsKey(rootChapterId)
              ? null
              : chapterMap,
          'sourceKey': sourceKey,
          'comicId': id,
          'thumbnails': null,
          'recommend': null,
          'isFavorite': false,
          'subId': null,
          'likesCount': null,
          'isLiked': null,
          'commentCount': null,
          'uploader': null,
          'uploadTime': null,
          'updateTime': null,
          'url': null,
          'maxPage': null,
        }),
      );
    } catch (e) {
      return Res.error(e.toString());
    }
  }

  static Future<Res<List<String>>> loadComicPages(String id, String? ep) async {
    final config = WebDavLibraryConfig.fromSettings();
    if (!config.isValid) {
      return const Res.error('Invalid WebDAV comic library configuration');
    }
    try {
      final path = ep == null || ep == rootChapterId
          ? config.childDirectoryPath(id)
          : config.childDirectoryPath('$id/$ep');
      final entries = await ops.readDir(config, path);
      final files = _imageEntries(entries)
          .where((entry) => !_isNamedCover(entry.name))
          .map((entry) => config.childFilePath(path, entry.name))
          .toList();
      if (files.isEmpty) {
        return const Res.error('No images found in the WebDAV chapter');
      }
      return Res(files);
    } catch (e) {
      return Res.error(e.toString());
    }
  }

  static Future<Map<String, dynamic>> getImageLoadingConfig(
    String imageKey,
    String comicId,
    String epId,
  ) async {
    final config = WebDavLibraryConfig.fromSettings();
    return {'url': config.fileUrl(imageKey), 'headers': config.authHeaders};
  }

  static Map<String, dynamic> getThumbnailLoadingConfig(String imageKey) {
    final config = WebDavLibraryConfig.fromSettings();
    if (imageKey.startsWith('cover.')) {
      return {'headers': config.authHeaders};
    }
    return {'url': config.fileUrl(imageKey), 'headers': config.authHeaders};
  }

  static List<WebDavLibraryEntry> _imageEntries(
    List<WebDavLibraryEntry> entries,
  ) {
    final result = entries
        .where((entry) => !entry.isDirectory)
        .where((entry) => !_isIgnoredEntry(entry.name))
        .where((entry) => _isImageFile(entry.name))
        .toList();
    result.sort((a, b) => _compareNames(a.name, b.name));
    return result;
  }

  static WebDavLibraryEntry? _findNamedCover(List<WebDavLibraryEntry> entries) {
    return _imageEntries(
      entries,
    ).firstWhereOrNull((entry) => _isNamedCover(entry.name));
  }

  static bool _isImageFile(String name) {
    final extension = _extension(name);
    return _imageExtensions.contains(extension);
  }

  static bool _isNamedCover(String name) {
    final lower = name.toLowerCase();
    final extension = _extension(lower);
    if (!_imageExtensions.contains(extension)) return false;
    return lower.substring(0, lower.length - extension.length - 1) == 'cover';
  }

  static bool _isIgnoredEntry(String name) {
    final lower = name.toLowerCase();
    return name == '__MACOSX' ||
        name == '.DS_Store' ||
        name.startsWith('._') ||
        name.startsWith('.') ||
        _archiveExtensions.contains(_extension(lower));
  }

  static String _extension(String name) {
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) return '';
    return name.substring(index + 1).toLowerCase();
  }

  static int _compareNames(String a, String b) {
    final aBase = a.split('.').first;
    final bBase = b.split('.').first;
    final aIndex = int.tryParse(aBase);
    final bIndex = int.tryParse(bBase);
    if (aIndex != null && bIndex != null) {
      return aIndex.compareTo(bIndex);
    }
    return a.compareTo(b);
  }
}
