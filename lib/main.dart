import 'dart:io';

import 'package:github/server.dart' as GitHub;
import 'package:readme_generator/readme_generator.dart';
import 'package:yaml/yaml.dart' as YAML;

void main({
  bool debugLog: true,
  bool generateOutputFile: false,
  String outputFileName: "output.md",
}) async {
  void log(String message) {
    if (debugLog) print(message);
  }

  log("-- RUNNING ReadmeGenerator (${new DateTime.now()}) --");
  File configFile = new File("config.yaml");

  YAML.YamlMap config =
      YAML.loadYaml(configFile.readAsStringSync());

  ReadmeGenerator generator = new ReadmeGenerator.fromYAML(config);

  generator.enableLogging();

  String result;

  try {
    result = await generator.generateReadme();
  } on GitHub.UnknownError catch (e) {
    if (e.message.contains("API rate limit")) {
      log("GitHub rate limit reached.");
      log("Next rate limit reset: ${e.github.rateLimitReset.toLocal()} (U ${e.github.rateLimitReset.toLocal().millisecondsSinceEpoch/1000.toInt()} sec.)");
    } else
      log("Unknown error: $e");
  }

  if (result != null) {
    log("README GENERATED");

    log("RESULT:\n" + result.split('\n').map((line) => "\t" + line).join('\n'));

    if (generateOutputFile) {
      File outputFile = File(outputFileName);
      if (outputFile.existsSync()) outputFile.deleteSync();
      outputFile.writeAsStringSync(result);
    }
  }

  log("Exiting.");
  exit((result != null) ? 0 : 1);
}
