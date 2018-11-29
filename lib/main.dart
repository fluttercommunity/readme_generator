import 'dart:io';

import 'package:github/server.dart' as GitHub;
import 'package:readme_generator/github_tools.dart';
import 'package:readme_generator/readme_generator.dart';
import 'package:yaml/yaml.dart' as YAML;

void main({
  bool debugLog: true,
  bool generateOutputFile: false,
  bool logResult: true,
  String outputFileName: "output.md",
}) async {
  void log(String message) {
    if (debugLog) print("-- $message --");
  }

  log("ReadmeGenerator (${new DateTime.now()})");

  String ipAddress = await GitHubTools.getFile("http://icanhazip.com/");
  log("IP: ${ipAddress.trim()}");

  File configFile = new File("config.yaml");
  YAML.YamlMap config = YAML.loadYaml(configFile.readAsStringSync());

  final String gitHubAuthorizationTokenName =
      config["github_authorization_token_name"] ?? "GITHUB_AUTHORIZATION_TOKEN";

  Map<String, String> envVars = Platform.environment;
  if (!envVars.containsKey(gitHubAuthorizationTokenName)) {
    throw new ArgumentError(
        "No GitHub authorization token provided: environment variable '$gitHubAuthorizationTokenName' not found.");
  }
  final String gitHubAuthorizationToken = envVars[gitHubAuthorizationTokenName];

  ReadmeGenerator generator = new ReadmeGenerator.fromYAML(config);
  if (debugLog) generator.enableLogging();

  String result;

  try {
    if (config["use_output_file_as_generated_readme"] != null &&
        config["use_output_file_as_generated_readme"]) {
      File outputFile = new File(outputFileName);
      result = outputFile.readAsStringSync();
    } else {
      result = await generator.generateReadme();
    }
  } on GitHub.UnknownError catch (e) {
    if (e.message.contains("API rate limit")) {
      log("GitHub rate limit reached. Next rate limit reset: ${e.github.rateLimitReset.toLocal()} (U ${e.github.rateLimitReset.toLocal().millisecondsSinceEpoch / 1000.toInt()} sec.)");
    } else
      log("Unknown error: $e");
  }

  if (result != null) {
    log("README GENERATED");

    if (logResult)
      log("RESULT:\n" +
          result.split('\n').map((line) => "\t" + line).join('\n'));

    if (generateOutputFile) {
      File outputFile = new File(outputFileName);
      if (outputFile.existsSync()) outputFile.deleteSync();
      outputFile.writeAsStringSync(result);
    }

    try {
      log("Uploading to git...");
      await generator.uploadReadmeToRepository(
          content: result, authorizationToken: gitHubAuthorizationToken);
    } catch (e) {
      log('Unknown error: $e');
    }
  }

  log("Exiting.");
  exit((result != null) ? 0 : 1);
}
