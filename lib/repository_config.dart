import 'dart:async';

import 'package:github/server.dart' as GitHub;
import 'package:meta/meta.dart';
import 'package:readme_generator/github_tools.dart';
import 'package:yaml/yaml.dart' as YAML;

class RepositoryConfigFileError extends Error {
  RepositoryConfigFileError({
    this.fileNotFound = false,
    String errorDescription,
  }) {
    this.message =
        (this.fileNotFound) ? "File not found" : "File or YAML is invalid";
    this.message += (errorDescription != null && errorDescription.isNotEmpty)
        ? ": $message"
        : ".";
  }

  final bool fileNotFound;
  String message;
}

class RepositoryConfig {
  RepositoryConfig({
    this.ignore: false,
    this.packageName,
    this.packageDescription,
    this.maintainerName,
    this.maintainerUsername,
  }) {
    if (ignore == false) assert(packageName != null && packageName.isNotEmpty);
  }

  final bool ignore;
  final String packageName;
  final String packageDescription;
  final String maintainerName;
  final String maintainerUsername;
  String repositoryName;

  factory RepositoryConfig.fromYAML(YAML.YamlMap config) {
    Map<String, String> maintainerData = {};
    if (config["maintainer"] != null &&
        (config["maintainer"] as String).isNotEmpty) {
      maintainerData = RepositoryConfig.getMaintainerInfo(
        data: config["maintainer"] as String,
      );
    }

    return new RepositoryConfig(
      ignore: config["ignore"] ?? false,
      maintainerName: maintainerData["name"],
      maintainerUsername: maintainerData["username"],
      packageDescription: config["description"],
      packageName: config["name"],
    );
  }

  static Future<RepositoryConfig> fromRepository(
    GitHub.Repository repository, {
    @required String configFileName,
  }) async {
    GitHubTools temporaryTools = await GitHubTools.fromRepository(repository);
    String configString = await temporaryTools.getFileFromRepository(repository,
        fileName: configFileName);
    if (configString.startsWith("404")) {
      throw new RepositoryConfigFileError(fileNotFound: true);
    }
    try {
      YAML.YamlMap config = YAML.loadYaml(configString);
      return new RepositoryConfig.fromYAML(config)
        ..repositoryName = repository.name;
    } on FormatException {
      throw new RepositoryConfigFileError(fileNotFound: false);
    }
  }

  static Map<String, String> getMaintainerInfo({
    @required String data,
  }) {
    String name, username;
    try {
      name = data.substring(0, data.indexOf("(") - 1).trim();
      int usernameStartIndex =
          ((data.contains("@")) ? data.indexOf("@") : data.indexOf("(")) + 1;
      username = data.substring(usernameStartIndex, data.indexOf(")"));
    } catch (e) {
      name = null;
      username = null;
    }

    return {
      "name": name,
      "username": username,
    };
  }
}
