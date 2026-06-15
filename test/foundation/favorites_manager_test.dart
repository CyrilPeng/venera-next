import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/favorites.dart';

FavoriteItem _favorite(String id) {
  return FavoriteItem(
    id: id,
    name: 'Comic $id',
    coverPath: 'cover-$id.jpg',
    author: 'Author',
    type: ComicType.local,
    tags: const ['tag'],
  );
}

bool _sqliteAvailable() {
  try {
    final db = sqlite3.openInMemory();
    db.dispose();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  test(
    'empty batch favorite operations do not notify listeners',
    () async {
      final dataDir = Directory.systemTemp.createTempSync(
        'venera-favorites-data-',
      );
      final cacheDir = Directory.systemTemp.createTempSync(
        'venera-favorites-cache-',
      );
      addTearDown(() async {
        await LocalFavoritesManager().debugWaitForHashedIdsRefresh();
        try {
          LocalFavoritesManager().close();
        } catch (_) {
          // ignore cleanup failures in partially initialized tests
        }
        LocalFavoritesManager.cache = null;
        if (dataDir.existsSync()) {
          dataDir.deleteSync(recursive: true);
        }
        if (cacheDir.existsSync()) {
          cacheDir.deleteSync(recursive: true);
        }
      });

      App.dataPath = dataDir.path;
      App.cachePath = cacheDir.path;
      LocalFavoritesManager.cache = null;

      final manager = LocalFavoritesManager();
      await manager.init();
      manager.createFolder('source');
      manager.createFolder('target');

      var notifyCount = 0;
      void listener() {
        notifyCount++;
      }

      manager.addListener(listener);
      addTearDown(() => manager.removeListener(listener));

      manager.batchMoveFavorites('source', 'target', <FavoriteItem>[]);
      manager.batchCopyFavorites('source', 'target', <FavoriteItem>[]);
      manager.batchDeleteComics('source', <FavoriteItem>[]);
      manager.batchDeleteComicsInAllFolders([]);

      expect(notifyCount, 0);
      expect(manager.count('source'), 0);
      expect(manager.count('target'), 0);
    },
    skip: _sqliteAvailable() ? false : 'sqlite3 native library is unavailable',
  );

  test(
    'batchMoveFavorites notifies after counts are updated',
    () async {
      final dataDir = Directory.systemTemp.createTempSync(
        'venera-favorites-data-',
      );
      final cacheDir = Directory.systemTemp.createTempSync(
        'venera-favorites-cache-',
      );
      addTearDown(() async {
        await LocalFavoritesManager().debugWaitForHashedIdsRefresh();
        try {
          LocalFavoritesManager().close();
        } catch (_) {
          // ignore cleanup failures in partially initialized tests
        }
        LocalFavoritesManager.cache = null;
        if (dataDir.existsSync()) {
          dataDir.deleteSync(recursive: true);
        }
        if (cacheDir.existsSync()) {
          cacheDir.deleteSync(recursive: true);
        }
      });

      App.dataPath = dataDir.path;
      App.cachePath = cacheDir.path;
      LocalFavoritesManager.cache = null;

      final manager = LocalFavoritesManager();
      await manager.init();
      manager.createFolder('source');
      manager.createFolder('target');
      final first = _favorite('first');
      final second = _favorite('second');
      manager.addComic('source', first);
      manager.addComic('source', second);

      final observedCounts = <(int source, int target)>[];
      var isBatching = false;
      void listener() {
        if (isBatching) {
          observedCounts.add((
            manager.folderComics('source'),
            manager.folderComics('target'),
          ));
        }
      }

      manager.addListener(listener);
      addTearDown(() => manager.removeListener(listener));

      isBatching = true;
      manager.batchMoveFavorites('source', 'target', [first, second]);
      isBatching = false;

      expect(observedCounts, [(0, 2)]);
      expect(manager.count('source'), 0);
      expect(manager.count('target'), 2);
    },
    skip: _sqliteAvailable() ? false : 'sqlite3 native library is unavailable',
  );
}
