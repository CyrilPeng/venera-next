import 'dart:convert';

import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_storage/comic_storage.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/extensions.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/foundation/res.dart';
import 'package:venera_next/foundation/throttled_task_runner.dart';
import 'package:venera_next/network/webdav.dart';
import 'package:webdav_client/webdav_client.dart' hide File;

class WebDavLibraryConfig {
  WebDavLibraryConfig({
    required String url,
    required String user,
    required String pass,
    required String remotePath,
  }) : endpoint = WebDavEndpoint(url: url, user: user, password: pass),
       remotePath = normalizeWebDavDirectoryPath(
         remotePath,
         fallback: '/venera_comics/',
       );

  final WebDavEndpoint endpoint;
  final String remotePath;

  String get url => endpoint.url;

  String get user => endpoint.user;

  String get pass => endpoint.password;

  bool get isValid => endpoint.isValid;

  Map<String, String> get authHeaders => endpoint.authHeaders;

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
    return childDirectoryPathFrom(remotePath, name);
  }

  String childFilePath(String parent, String name) {
    return joinWebDavFilePath(parent, name);
  }

  String childDirectoryPathFrom(String parent, String name) {
    return joinWebDavDirectoryPath(parent, name);
  }

  String fileUrl(String remoteFilePath) => endpoint.fileUrl(remoteFilePath);
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

  Future<String> readText(WebDavLibraryConfig config, String remotePath);
}

class _WebDavLibraryOps implements WebDavLibraryOps {
  Client _client(WebDavLibraryConfig config) {
    return config.endpoint.createClient();
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

  @override
  Future<String> readText(WebDavLibraryConfig config, String remotePath) async {
    final bytes = await _client(config).read(remotePath);
    return utf8.decode(bytes, allowMalformed: false);
  }
}

class WebDavLibrarySource {
  const WebDavLibrarySource._();

  static const sourceKey = 'webdav_library';
  static const explorePageTitle = 'WebDAV Library';
  static const rootChapterId = '__root__';
  static const rootChapterTitle = 'Images';
  static const _metadataFileName = 'metadata.json';
  static const _metadataChapterPrefix = '__cbz_range_';

  static final _snapshotCache = <String, _WebDavComicSnapshot>{};
  static WebDavLibraryOps _ops = _WebDavLibraryOps();

  static WebDavLibraryOps get ops => _ops;

  static set ops(WebDavLibraryOps value) {
    _ops = value;
    _snapshotCache.clear();
  }

  static void resetOps() {
    _ops = _WebDavLibraryOps();
    _snapshotCache.clear();
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
      _snapshotCache.clear();
      final entries = List<WebDavLibraryEntry>.from(
        await ops.readDir(config, config.remotePath),
      );
      final directories =
          entries
              .where((entry) => entry.isDirectory)
              .where((entry) => !_isIgnoredEntry(entry.name))
              .toList()
            ..sort((a, b) => compareComicFileNames(a.name, b.name));
      final snapshots = <String, _WebDavComicSnapshot>{};
      await runThrottledTasks(
        directories,
        concurrency: 4,
        throttleEvery: 0,
        run: (entry) async {
          try {
            snapshots[entry.name] = await _loadSnapshot(config, entry.name);
          } catch (e) {
            Log.warning(
              'WebDAV Library',
              'Failed to inspect ${entry.name}: $e',
            );
          }
        },
      );
      final comics = directories.map((entry) {
        final snapshot = snapshots[entry.name];
        return Comic(
          snapshot?.title ?? entry.name,
          snapshot?.cover ?? '',
          entry.name,
          snapshot?.author,
          snapshot?.listTags ?? const ['WebDAV'],
          '',
          sourceKey,
          null,
          null,
        );
      }).toList();
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
      final snapshot = await _loadSnapshot(config, id);
      return Res(
        ComicDetails.fromJson({
          'title': snapshot.title,
          'subtitle': snapshot.author,
          'cover': snapshot.cover,
          'description': '',
          'tags': snapshot.detailTags,
          'chapters':
              snapshot.chapters.length == 1 &&
                  snapshot.chapters.containsKey(rootChapterId)
              ? null
              : snapshot.chapters,
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
      final comicPath = config.childDirectoryPath(id);
      if (ep != null &&
          ep != rootChapterId &&
          !ep.startsWith(_metadataChapterPrefix)) {
        final path = config.childDirectoryPathFrom(comicPath, ep);
        final entries = List<WebDavLibraryEntry>.from(
          await ops.readDir(config, path),
        );
        final files = _imageEntries(entries)
            .where((entry) => !isNamedComicCover(entry.name))
            .map((entry) => config.childFilePath(path, entry.name))
            .toList();
        if (files.isEmpty) {
          return const Res.error('No images found in the WebDAV chapter');
        }
        return Res(files);
      }

      final snapshot = await _loadSnapshot(config, id);
      final metadataChapter = ep == null ? null : snapshot.metadataChapters[ep];
      if (metadataChapter != null) {
        final files = snapshot.rootImages
            .sublist(metadataChapter.start - 1, metadataChapter.end)
            .map((entry) => config.childFilePath(comicPath, entry.name))
            .toList();
        return Res(files);
      }
      if (ep?.startsWith(_metadataChapterPrefix) == true) {
        return const Res.error('Invalid WebDAV metadata chapter');
      }
      if (ep == null || ep == rootChapterId) {
        final files = snapshot.rootImages
            .map((entry) => config.childFilePath(comicPath, entry.name))
            .toList();
        if (files.isEmpty) {
          return const Res.error('No images found in the WebDAV chapter');
        }
        return Res(files);
      }
      return const Res.error('No images found in the WebDAV chapter');
    } catch (e) {
      return Res.error(e.toString());
    }
  }

  static Future<_WebDavComicSnapshot> _loadSnapshot(
    WebDavLibraryConfig config,
    String id,
  ) async {
    final cacheKey = jsonEncode([
      config.url,
      config.user,
      config.remotePath,
      id,
    ]);
    final cached = _snapshotCache[cacheKey];
    if (cached != null) return cached;
    final snapshot = await _buildSnapshot(config, id);
    _snapshotCache[cacheKey] = snapshot;
    return snapshot;
  }

  static Future<_WebDavComicSnapshot> _buildSnapshot(
    WebDavLibraryConfig config,
    String id,
  ) async {
    final comicPath = config.childDirectoryPath(id);
    final entries = List<WebDavLibraryEntry>.from(
      await ops.readDir(config, comicPath),
    );
    final rootImages = _imageEntries(
      entries,
    ).where((entry) => !isNamedComicCover(entry.name)).toList();
    final directories =
        entries
            .where((entry) => entry.isDirectory)
            .where((entry) => !_isIgnoredEntry(entry.name))
            .toList()
          ..sort((a, b) => compareComicFileNames(a.name, b.name));
    final metadata = await _readMetadata(
      config,
      comicPath,
      entries,
      pageCount: rootImages.length,
    );

    final metadataChapters = <String, ComicChapter>{};
    final chapterMap = <String, String>{};
    if (metadata?.chapters?.isNotEmpty == true) {
      for (var index = 0; index < metadata!.chapters!.length; index++) {
        final chapter = metadata.chapters![index];
        final chapterId = '$_metadataChapterPrefix$index';
        metadataChapters[chapterId] = chapter;
        chapterMap[chapterId] = chapter.title;
      }
    } else {
      for (final directory in directories) {
        chapterMap[directory.name] = directory.name;
      }
      if (chapterMap.isEmpty && rootImages.isNotEmpty) {
        chapterMap[rootChapterId] = rootChapterTitle;
      }
    }
    if (chapterMap.isEmpty) {
      throw const FormatException(
        'No images found in the WebDAV comic directory',
      );
    }

    final namedCover = _findNamedCover(entries);
    String? coverPath = namedCover == null
        ? null
        : config.childFilePath(comicPath, namedCover.name);
    if (rootImages.isNotEmpty) {
      coverPath ??= config.childFilePath(comicPath, rootImages.first.name);
    }
    if (coverPath == null) {
      for (final directory in directories) {
        final chapterPath = config.childDirectoryPathFrom(
          comicPath,
          directory.name,
        );
        try {
          final chapterEntries = List<WebDavLibraryEntry>.from(
            await ops.readDir(config, chapterPath),
          );
          final chapterCover = _findNamedCover(chapterEntries);
          final chapterPages = _imageEntries(
            chapterEntries,
          ).where((entry) => !isNamedComicCover(entry.name)).toList();
          final coverEntry = chapterCover ?? chapterPages.firstOrNull;
          if (coverEntry != null) {
            coverPath = config.childFilePath(chapterPath, coverEntry.name);
            break;
          }
        } catch (e) {
          Log.warning(
            'WebDAV Library',
            'Failed to inspect chapter cover at $chapterPath: $e',
          );
        }
      }
    }

    final metadataTitle = metadata?.title.trim() ?? '';
    return _WebDavComicSnapshot(
      title: metadataTitle.isEmpty ? id : metadataTitle,
      author: metadata?.author ?? '',
      tags: metadata?.tags ?? const [],
      cover: coverPath ?? '',
      chapters: chapterMap,
      metadataChapters: metadataChapters,
      rootImages: rootImages,
    );
  }

  static Future<ComicMetaData?> _readMetadata(
    WebDavLibraryConfig config,
    String comicPath,
    List<WebDavLibraryEntry> entries, {
    required int pageCount,
  }) async {
    final metadataEntry = entries.firstWhereOrNull(
      (entry) =>
          !entry.isDirectory && entry.name.toLowerCase() == _metadataFileName,
    );
    if (metadataEntry == null) return null;

    final metadataPath = config.childFilePath(comicPath, metadataEntry.name);
    try {
      final decoded = jsonDecode(await ops.readText(config, metadataPath));
      if (decoded is! Map) {
        throw const FormatException('metadata.json must contain an object');
      }
      final metadata = ComicMetaData.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      metadata.validateChapterRanges(pageCount: pageCount);
      return metadata;
    } catch (e) {
      Log.warning(
        'WebDAV Library',
        'Ignoring invalid metadata at $metadataPath: $e',
      );
      return null;
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
    return sortedComicImageEntries(
      entries.where((entry) => !entry.isDirectory),
      nameOf: (entry) => entry.name,
    );
  }

  static WebDavLibraryEntry? _findNamedCover(List<WebDavLibraryEntry> entries) {
    return findNamedComicCover(
      _imageEntries(entries),
      nameOf: (entry) => entry.name,
    );
  }

  static bool _isIgnoredEntry(String name) {
    return isIgnoredComicStorageEntry(name) || isComicArchiveFileName(name);
  }
}

class _WebDavComicSnapshot {
  const _WebDavComicSnapshot({
    required this.title,
    required this.author,
    required this.tags,
    required this.cover,
    required this.chapters,
    required this.metadataChapters,
    required this.rootImages,
  });

  final String title;
  final String author;
  final List<String> tags;
  final String cover;
  final Map<String, String> chapters;
  final Map<String, ComicChapter> metadataChapters;
  final List<WebDavLibraryEntry> rootImages;

  List<String> get listTags => <String>{'WebDAV', ...tags}.toList();

  Map<String, List<String>> get detailTags => {
    'Source': const ['WebDAV'],
    if (tags.isNotEmpty) 'Tags': tags,
  };
}
