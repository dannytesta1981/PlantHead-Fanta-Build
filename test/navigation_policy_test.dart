import 'package:flutter_test/flutter_test.dart';
import 'package:planthead_fanta/core/navigation_policy.dart';

void main() {
  group('Origin boundary', () {
    test('only exact official HTTPS origin is privileged', () {
      expect(
        NavigationPolicy.isOfficial(
          Uri.parse('https://leghe.fantacalcio.it/lega'),
        ),
        isTrue,
      );
      for (final text in [
        'http://leghe.fantacalcio.it/',
        'https://leghe.fantacalcio.it.evil.example/',
        'https://evil-leghe.fantacalcio.it/',
        'https://leghe.fantacalcio.it:8443/',
        'https://name:secret@leghe.fantacalcio.it/',
        'file:///tmp/document.html',
      ]) {
        expect(
          NavigationPolicy.isOfficial(Uri.parse(text)),
          isFalse,
          reason: text,
        );
      }
    });
    test('blocks executable, local, insecure and custom schemes', () {
      for (final text in [
        'javascript:alert(1)',
        'data:text/html,test',
        'file:///etc/passwd',
        'http://example.com',
        'intent://app',
        'planthead://token',
      ]) {
        expect(
          NavigationPolicy.classify(Uri.parse(text)),
          LinkAction.block,
          reason: text,
        );
      }
      expect(NavigationPolicy.classify(null), LinkAction.block);
    });
    test('keeps real identity hosts but opens ordinary links externally', () {
      expect(
        NavigationPolicy.classify(
          Uri.parse('https://accounts.google.com/login'),
        ),
        LinkAction.web,
      );
      expect(
        NavigationPolicy.classify(
          Uri.parse('https://accounts.google.com.fake.test'),
        ),
        LinkAction.external,
      );
      expect(
        NavigationPolicy.classify(Uri.parse('https://www.fantacalcio.it/news')),
        LinkAction.external,
      );
      expect(
        NavigationPolicy.classify(Uri.parse('mailto:help@example.com')),
        LinkAction.external,
      );
      expect(
        NavigationPolicy.classify(Uri.parse('tel:+39000000000')),
        LinkAction.external,
      );
    });
  });
  test('browser handoff removes query and fragment authentication material', () {
    expect(
      NavigationPolicy.safeBrowserUri(
        Uri.parse(
          'https://leghe.fantacalcio.it/lega?token=secret#access_token=secret',
        ),
      ).toString(),
      'https://leghe.fantacalcio.it/lega',
    );
    expect(
      NavigationPolicy.safeBrowserUri(Uri.parse('https://evil.test/a')),
      isNull,
    );
  });
  test(
    'download names cannot traverse folders or inject invalid characters',
    () {
      expect(NavigationPolicy.safeFilename('../../rose.xlsx'), 'rose.xlsx');
      expect(
        NavigationPolicy.safeFilename(r'C:\Downloads\rose.xlsx'),
        'rose.xlsx',
      );
      expect(NavigationPolicy.safeFilename('..'), 'documento');
      expect(NavigationPolicy.safeFilename(null), 'documento');
      expect(NavigationPolicy.safeFilename('x' * 150).length, 100);
    },
  );
}
