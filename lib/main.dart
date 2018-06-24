import 'dart:convert' as Convert;
import 'dart:io';

import 'package:ReadmeGenerator/readme_generator.dart';

void main() async {
  print("-- Running ReadmeGenerator (${new DateTime.now()}) --");
  File configFile = new File("config.json");

  Map<String, dynamic> config =
      Convert.json.decode(await configFile.readAsString());

  ReadmeGenerator generator = new ReadmeGenerator.fromJSON(config);
  String result = await generator.generateReadme();

  print(result);

  String testFileName = "output.md";
  new File(testFileName).delete();
  new File(testFileName).writeAsStringSync(result);

  exit(0);
}
