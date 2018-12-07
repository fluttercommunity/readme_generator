import 'package:readme_generator/repository_config.dart';
import 'package:test/test.dart';

main() {
  group('Test Text Parsing', () {
    test('Should extract maintainer handle from pubspec field', () {
      final String source = "Lukas Dickie (@lukasgit)";
      final Map<String, String> expectedResult = {
        "name": "Lukas Dickie",
        "username": "lukasgit",
      };

      final Map<String, String> actualResult = RepositoryConfig.getMaintainerInfo(data: source);

      expect(actualResult["name"], expectedResult["name"]);
      expect(actualResult["username"], expectedResult["username"]);
    });
  });
}
