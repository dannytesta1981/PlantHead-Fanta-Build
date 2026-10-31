import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'navigation_policy.dart';

class DownloadService {
  static const maxBytes = 50 * 1024 * 1024;

  // Native cookies remain in the OS WebView store; read only for this user-
  // initiated same-origin download, never serialize them to disk or logs.
  Future<File> download(Uri uri, String? filename) async {
    if (!NavigationPolicy.isOfficial(uri)) {
      throw const DownloadException('Download esterno: aprilo nel browser.');
    }
    final directory = await getTemporaryDirectory();
    final folder = Directory('${directory.path}/fanta_downloads');
    await folder.create(recursive: true);
    final file = File(
      '${folder.path}/${DateTime.now().microsecondsSinceEpoch}_'
      '${NavigationPolicy.safeFilename(filename)}',
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    try {
      var current = uri;
      HttpClientResponse? response;
      for (var redirects = 0; redirects < 5; redirects++) {
        final request = await client
            .getUrl(current)
            .timeout(const Duration(seconds: 20));
        request.followRedirects = false;
        final cookies = await CookieManager.instance().getCookies(
          url: WebUri.uri(current),
        );
        if (cookies.isNotEmpty) {
          request.headers.set(
            HttpHeaders.cookieHeader,
            cookies.map((c) => '${c.name}=${c.value}').join('; '),
          );
        }
        response = await request.close().timeout(const Duration(seconds: 30));
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) {
            throw const DownloadException('Reindirizzamento non valido.');
          }
          final next = current.resolve(location);
          // No cookies or authenticated requests may cross the official origin.
          if (!NavigationPolicy.isOfficial(next)) {
            throw const DownloadException(
              'Il file è su un sito esterno. Usa il browser.',
            );
          }
          current = next;
          response = null;
          continue;
        }
        break;
      }
      if (response == null || response.statusCode != 200) {
        throw const DownloadException(
          'File non disponibile. Verifica l’accesso sul sito.',
        );
      }
      final type = response.headers.contentType?.mimeType ?? '';
      if (type == 'text/html') {
        throw const DownloadException(
          'Il sito richiede di nuovo il login, oppure il file non è pronto.',
        );
      }
      if (response.contentLength > maxBytes) {
        throw const DownloadException('File oltre 50 MB: usa il browser.');
      }
      sink = file.openWrite();
      var bytes = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes += chunk.length;
        if (bytes > maxBytes) {
          throw const DownloadException('File oltre 50 MB.');
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      return file;
    } catch (_) {
      await sink?.close();
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> clearTemporaryFiles() async {
    final root = await getTemporaryDirectory();
    final folder = Directory('${root.path}/fanta_downloads');
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}

class DownloadException implements Exception {
  const DownloadException(this.message);
  final String message;
}
