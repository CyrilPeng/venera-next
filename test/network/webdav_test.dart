import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/network/webdav.dart';

void main() {
  test('WebDavEndpoint normalizes credentials and builds auth headers', () {
    final endpoint = WebDavEndpoint(
      url: ' https://example.com/dav/ ',
      user: ' user ',
      password: ' pass ',
    );

    expect(endpoint.url, 'https://example.com/dav/');
    expect(endpoint.user, 'user');
    expect(endpoint.password, 'pass');
    expect(endpoint.authHeaders, {'authorization': 'Basic dXNlcjpwYXNz'});
  });

  test('WebDavEndpoint encodes each remote path segment', () {
    final endpoint = WebDavEndpoint(
      url: 'https://example.com/dav/',
      user: '',
      password: '',
    );

    expect(
      endpoint.fileUrl('/漫画/第 01 卷/001.jpg'),
      'https://example.com/dav/%E6%BC%AB%E7%94%BB/%E7%AC%AC%2001%20%E5%8D%B7/001.jpg',
    );
    expect(endpoint.authHeaders, isEmpty);
  });

  test('normalizes and joins WebDAV directory paths', () {
    expect(
      normalizeWebDavDirectoryPath('', fallback: '/fallback/'),
      '/fallback/',
    );
    expect(
      normalizeWebDavDirectoryPath(r'manga\books', fallback: '/fallback/'),
      '/manga/books/',
    );
    expect(joinWebDavFilePath('/manga/', r'Book\1.jpg'), '/manga/Book/1.jpg');
    expect(
      joinWebDavDirectoryPath('/manga', 'Book/Chapter 1'),
      '/manga/Book/Chapter 1/',
    );
  });

  test('rejects empty and traversing relative paths', () {
    expect(() => normalizeWebDavRelativePath(''), throwsFormatException);
    expect(
      () => normalizeWebDavRelativePath('../secret'),
      throwsFormatException,
    );
    expect(
      () => normalizeWebDavRelativePath('book/./page'),
      throwsFormatException,
    );
  });
}
