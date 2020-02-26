import 'dart:io';

import 'package:github/server.dart' as github;
import 'package:readme_generator/github_tools.dart';
import 'package:readme_generator/readme_generator.dart';
import 'package:yaml/yaml.dart' as yaml;

Future<void> main({
  bool debugLog = true,
  bool generateOutputFile = false,
  bool logResult = true,
  String outputFileName = 'output.md',
}) async {
  void log(String message) {
    if (debugLog) {
      print('-- $message --');
    }
  }

  log('ReadmeGenerator (${DateTime.now().toUtc()} UTC)');

  final ipAddress = await GitHubTools.getFile('http://icanhazip.com/');
  log('IP: ${ipAddress.trim()}');

  final configFile = File('config.yaml');
  final config = yaml.loadYaml(configFile.readAsStringSync());

  final gitHubAuthorizationTokenName = config['github_authorization_token_name'] ?? 'GITHUB_AUTHORIZATION_TOKEN';

  final gitHubAuthorizationToken = Platform.environment[gitHubAuthorizationTokenName];

  if (gitHubAuthorizationToken == null) {
    throw ArgumentError(
        'No GitHub authorization token provided: environment variable "$gitHubAuthorizationTokenName" not found.');
  }


  final generator = ReadmeGenerator.fromYAML(config);
  if (debugLog) {
    generator.enableLogging();
  }

  String result;

  try {
    if (config['use_output_file_as_generated_readme'] != null && config['use_output_file_as_generated_readme']) {
      final outputFile = File(outputFileName);
      result = outputFile.readAsStringSync();
    } else {
      result = await generator.generateReadme();
    }
  } on github.UnknownError catch (e) {
    if (e.message.contains('API rate limit')) {
      log('GitHub rate limit reached. Next rate limit reset: ${e.github.rateLimitReset.toLocal()} (U ${e.github.rateLimitReset.toLocal().millisecondsSinceEpoch / 1000.toInt()} sec.)');
    } else {
      log('Unknown error: $e');
    }
  }

  if (result != null) {
    log('README GENERATED');

    if (logResult) {
      log('RESULT:\n${result.split('\n').map((line) => '\t$line').join('\n')}');
    }

    if (generateOutputFile) {
      final outputFile = File(outputFileName);
      if (outputFile.existsSync()) {
        outputFile.deleteSync();
      }
      outputFile.writeAsStringSync(result);
    }

    try {
      log('Uploading to git...');
      await generator.uploadReadmeToRepository(content: result, authorizationToken: gitHubAuthorizationToken);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log('Unknown error: $e');
    }
  }

  log('Exiting.');
  exit((result != null) ? 0 : 1);
}
