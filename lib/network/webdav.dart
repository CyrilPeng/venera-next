import 'dart:convert';

import 'package:venera_next/network/app_dio.dart';
import 'package:webdav_client/webdav_client.dart';

class WebDavEndpoint {
  WebDavEndpoint({
    required String url,
    required String user,
    required String password,
  }) : url = url.trim(),
       user = user.trim(),
       password = password.trim();

  final String url;
  final String user;
  final String password;

  bool get isValid => url.isNotEmpty;

  Map<String, String> get authHeaders {
    if (user.isEmpty && password.isEmpty) return const {};
    final token = base64Encode(utf8.encode('$user:$password'));
    return {'authorization': 'Basic $token'};
  }

  Client createClient() {
    return newClient(
      url,
      user: user,
      password: password,
      adapter: RHttpAdapter(),
    );
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
}

String normalizeWebDavDirectoryPath(String path, {required String fallback}) {
  var result = path.trim().replaceAll('\\', '/');
  if (result.isEmpty) result = fallback.trim().replaceAll('\\', '/');
  if (!result.startsWith('/')) result = '/$result';
  if (!result.endsWith('/')) result = '$result/';
  return result;
}

String joinWebDavFilePath(String parent, String relativePath) {
  final path = normalizeWebDavRelativePath(relativePath);
  return '${_ensureTrailingSlash(parent)}$path';
}

String joinWebDavDirectoryPath(String parent, String relativePath) {
  return '${joinWebDavFilePath(parent, relativePath)}/';
}

String normalizeWebDavRelativePath(String value) {
  final segments = value
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty ||
      segments.any((segment) => segment == '.' || segment == '..')) {
    throw const FormatException('Invalid relative WebDAV path');
  }
  return segments.join('/');
}

String _ensureTrailingSlash(String path) {
  return path.endsWith('/') ? path : '$path/';
}
