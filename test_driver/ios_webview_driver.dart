import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [args]) async {
      final dir = Directory('build/feather');
      await dir.create(recursive: true);
      await File('${dir.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      final safe = Map<String, dynamic>.from(data ?? {});
      safe.remove('screenshots');
      await writeResponseData(
        safe,
        testOutputFilename: 'ios-webview-results',
        destinationDirectory: 'build/feather',
      );
    },
  );
}
