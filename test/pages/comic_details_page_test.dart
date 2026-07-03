import 'package:flutter_test/flutter_test.dart';
import 'package:venera/pages/comic_details_page/comic_page.dart';

void main() {
  test(
    'read-only comic info namespaces are not treated as searchable tags',
    () {
      expect(isReadOnlyComicInfoNamespaceForTesting('views'), isTrue);
      expect(isReadOnlyComicInfoNamespaceForTesting('浏览量'), isTrue);
      expect(isReadOnlyComicInfoNamespaceForTesting('last update'), isTrue);

      expect(isReadOnlyComicInfoNamespaceForTesting('artist'), isFalse);
      expect(isReadOnlyComicInfoNamespaceForTesting('language'), isFalse);
    },
  );
}
