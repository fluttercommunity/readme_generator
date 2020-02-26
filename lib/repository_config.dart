import 'dart:async';

import 'package:github/server.dart' as github;
import 'package:meta/meta.dart';
import 'package:readme_generator/github_tools.dart';
import 'package:yaml/yaml.dart' as yaml;

class RepositoryConfigFileError extends Error {
  RepositoryConfigFileError({
    this.fileNotFound = false,
    String errorDescription,
  }) {
    if (fileNotFound) {
      message = 'File not found';
    } else {
      message = 'File or YAML is invalid';
    }
    message += (errorDescription != null && errorDescription.isNotEmpty) ? ': $message' : '.';
  }

  final bool fileNotFound;
  String message;
}

class RepositoryConfig {
  RepositoryConfig({
    this.ignore = false,
    this.packageName,
    this.packageDescription,
    this.maintainerName,
    this.maintainerUsername,
  }) : assert(
          ignore == true || (packageName != null && packageName.isNotEmpty),
          'Package name must be provided.',
        );

  final bool ignore;
  final String packageName;
  final String packageDescription;
  final String maintainerName;
  final String maintainerUsername;
  String repositoryName;

  String get packageDescriptionEscaped {
    if (packageDescription == null) {
      return null;
    }

    final escapeCharacters = ['|'];

    var result = packageDescription;
    for (final char in escapeCharacters) {
      // FIXME: Make this prettier.
      result = result.replaceAll(char, '-');
    }

    return result;
  }

  factory RepositoryConfig.fromYAML(yaml.YamlMap config) {
    final maintainerData = <String, String>{};
    if (config['maintainer'] != null && (config['maintainer'] as String).isNotEmpty) {
      maintainerData.addAll(
        RepositoryConfig.getMaintainerInfo(
          data: config['maintainer'] as String,
        ),
      );
    }

    return RepositoryConfig(
      ignore: config['ignore'] ?? false,
      maintainerName: maintainerData['name'],
      maintainerUsername: maintainerData['username'],
      packageDescription: config['description'],
      packageName: config['name'],
    );
  }

  static Future<RepositoryConfig> fromRepository(
    github.Repository repository, {
    @required String configFileName,
  }) async {
    final temporaryTools = await GitHubTools.fromRepository(repository);
    final configString = await temporaryTools.getFileFromRepository(repository, fileName: configFileName);
    if (configString.startsWith('404')) {
      throw RepositoryConfigFileError(fileNotFound: true);
    }
    try {
      final config = yaml.loadYaml(configString);
      return RepositoryConfig.fromYAML(config)..repositoryName = repository.name;
    } on FormatException {
      throw RepositoryConfigFileError(fileNotFound: false);
    }
  }

  static Map<String, String> getMaintainerInfo({
    @required String data,
  }) {
    String name;
    String username;

    try {
      name = data.substring(0, data.indexOf('(') - 1).trim();
      final usernameStartIndex = ((data.contains('@')) ? data.indexOf('@') : data.indexOf('(')) + 1;
      username = data.substring(usernameStartIndex, data.indexOf(')'));
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      name = null;
      username = null;
    }

    return {
      'name': name,
      'username': username,
    };
  }
}
