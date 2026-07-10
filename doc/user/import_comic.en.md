# Import Comic

## Introduction

VeneraNext supports importing comics from local files.
However, the comic files must be in a specific format.

## Restore Local Downloads

If you migrated the app and kept the local download folder but lost `local.db`,
you can restore the local database by scanning the current local path.

- Open `Local` -> `Import` -> `Restore local downloads`.
- The app scans the current local storage path and rebuilds entries.
- It does not copy files or add favorites.
- Duplicates (same title or directory) are skipped.

Make sure the local storage path in Settings points to the folder that contains
the downloaded comics before running this.

## Comic Directory

A directory considered as a comic directory only if it follows one of the following two types of structure:

**Without Chapter**

```
comic_directory
├── cover.[ext]
├── img1.[ext]
├── img2.[ext]
├── img3.[ext]
├── ...
```

**With Chapter**

```
comic_directory
├── cover.[ext]
├── chapter1
│   ├── img1.[ext]
│   ├── img2.[ext]
│   ├── img3.[ext]
│   ├── ...
├── chapter2
│   ├── img1.[ext]
│   ├── img2.[ext]
│   ├── img3.[ext]
│   ├── ...
├── ...
```

The file name can be anything, but the extension must be a valid image extension.

The page order is determined by the file name. App will sort the files by name and display them in that order.

Cover image is optional. 
If there is a file named `cover.[ext]` in the directory, it will be considered as the cover image.
Otherwise, the first image will be considered as the cover image.

The name of directory will be used as comic title. And the name of chapter directory will be used as chapter title.

## Archive

VeneraNext supports importing comics from archive files.

Archive files are intended for import, export, backup, migration, and distribution. They must follow [Comic Book Archive](https://en.wikipedia.org/wiki/Comic_book_archive_file) format.

Currently, VeneraNext supports the following archive formats:
- `.cbz`
- `.cb7`
- `.zip`
- `.7z`

An archive may contain images directly, or it may contain one top-level folder.
If the top-level folder contains chapter folders, VeneraNext imports those
folders as chapters.

```text
Cat's Eye.cbz
└── Cat's Eye
    ├── cover.jpg
    ├── Volume 01
    │   ├── 001.jpg
    │   └── 002.jpg
    └── Volume 02
        ├── 001.jpg
        └── 002.jpg
```

If there is no `cover.[ext]` in the root folder, the first image from the first
chapter is used as the cover.

## WebDAV Online Library

The WebDAV comic library is an online reading channel. It is separate from local import/export and WebDAV CBZ archive backup.

Online reading only supports remote directory image structure. The app lists directories and loads images on demand; remote CBZ/ZIP/7Z files are not used for online preview.

Recommended structure:

```text
/venera_comics/
└── Cat's Eye
    ├── cover.jpg
    ├── Volume 01
    │   ├── 001.jpg
    │   └── 002.jpg
    └── Volume 02
        ├── 001.jpg
        └── 002.jpg
```

CBZ/ZIP/7Z files can still be uploaded, downloaded, and restored through WebDAV archive backup, but they are backup and distribution formats rather than online reading formats.
