import 'dart:async';
import 'dart:convert' as Convert;

import 'package:github/server.dart' as GitHub;
import 'package:meta/meta.dart';
import 'package:readme_generator/github_tools.dart';

class RepositoryConfigFileError extends Error {
  RepositoryConfigFileError({
    this.fileNotFound = false,
    String errorDescription,
  }) {
    this.message =
        (this.fileNotFound) ? "File not found" : "File or JSON is invalid";
    this.message += (errorDescription != null && errorDescription.isNotEmpty)
        ? ": $message"
        : ".";
  }

  final bool fileNotFound;
  String message;
}

class RepositoryConfig {
  RepositoryConfig({
    @required this.isPackage,
    this.packageName,
    this.packageDescription,
    this.maintainerName,
    this.maintainerUsername,
    this.pubUrl,
    this.pubPackageName,
  }) {
    if (isPackage == false)
      assert(packageName != null && packageName.isNotEmpty);
  }

  final bool isPackage;
  final String packageName;
  final String packageDescription;
  final String maintainerName;
  final String maintainerUsername;
  final String pubUrl;
  final String pubPackageName;
  String repositoryName;

  factory RepositoryConfig.fromJSON(Map<String, dynamic> config) {
    return new RepositoryConfig(
      isPackage: config["is_package"],
      maintainerName: config["maintainer_name"],
      maintainerUsername: config["maintainer_username"],
      packageDescription: config["package_description"],
      packageName: config["package_name"],
      pubUrl: config["pub_url"],
      pubPackageName: config["pub_package_name"],
    );
  }

  static Future<RepositoryConfig> fromRepository(
    GitHub.Repository repository, {
    @required String configFileName,
  }) async {
    GitHubTools temporaryTools = await GitHubTools.fromRepository(repository);
    String configString = await temporaryTools.getFileFromRepository(repository,
        fileName: configFileName);
    if (configString.startsWith("404"))
      throw new RepositoryConfigFileError(fileNotFound: true);
    try {
      Map<String, dynamic> config = Convert.json.decode(configString);
      if (config["is_package"] == null)
        throw new RepositoryConfigFileError(
            fileNotFound: false,
            errorDescription: "'is_package' field not defined.");
      if (config["is_package"] is! bool)
        throw new RepositoryConfigFileError(
            fileNotFound: false,
            errorDescription: "'is_package' field is not a bool.");

      return new RepositoryConfig.fromJSON(config)..repositoryName = repository.name;
    } on FormatException {
      throw new RepositoryConfigFileError(fileNotFound: false);
    }
  }
}
