import 'dart:async';

import 'package:github/server.dart' as GitHub;
import 'package:meta/meta.dart';
import 'package:readme_generator/repository_config.dart';
import 'package:readme_generator/github_tools.dart';
import 'package:yaml/yaml.dart' as YAML;

class ReadmeGenerator {
  ReadmeGenerator({
    @required this.organizationName,
    @required this.mainRepositoryName,
    @required this.repositoryConfigFileName,
    @required this.markdownTableName,
    @required this.headerTextFileName,
  });

  final String organizationName,
      mainRepositoryName,
      repositoryConfigFileName,
      markdownTableName,
      headerTextFileName;

  bool _log = false;
  int _logLevel = 0;

  GitHubTools _git;

  factory ReadmeGenerator.fromYAML(YAML.YamlMap config) {
    return new ReadmeGenerator(
      organizationName: config["organization_name"],
      mainRepositoryName: config["main_repository_name"],
      repositoryConfigFileName: config["repository_config_file_name"],
      markdownTableName: config["markdown_table_name"],
      headerTextFileName: config["header_text_file_name"],
    );
  }

  void enableLogging() => _log = true;

  void disableLogging() => _log = false;

  void indentLog() => _logLevel += 1;

  void unIndentLog() => _logLevel -= (_logLevel <= 0) ? 0 : 1;

  void log(String message,
      {bool error: false, bool warn: false, bool positive: false}) {
    if (_log) {
      String text = (" " * (_logLevel * 2)) + message;
      print(text);
    }
  }

  void initialize() async => this._git ??=
      await GitHubTools.fromOrganizationName(this.organizationName);

  Future<String> generateReadme() async {
    log("Generating readme...");
    indentLog();
    await initialize();
    String headerText = await this.getHeaderText();
    String packageTable = await this.generateTable();
    unIndentLog();
    log("Done generating readme.", positive: true);
    return headerText + "\n" + packageTable;
  }

  Future<String> generateTable() async {
    log("Generating table...");
    indentLog();
    await initialize();
    List<GitHub.Repository> repositoriesToParse =
        await this._git.getAllRepositories();

    String result =
        await this._generateTableForRepositories(repositoriesToParse);

    unIndentLog();
    log("Done generating table.", positive: true);
    return result;
  }

  Future<String> _generateTableForRepositories(
      List<GitHub.Repository> repositories) async {
    log("Generating table for repositories\n\t${repositories.map<String>((repository) => repository.name).join(', ')}...");
    log("(Repository config file name: '$repositoryConfigFileName')");
    indentLog();
    String result = "";

    for (GitHub.Repository repository in repositories) {
      log("- " + repository.name);
      indentLog();
      log("Getting repository config...");
      try {
        RepositoryConfig repositoryConfig =
            await RepositoryConfig.fromRepository(
          repository,
          configFileName: this.repositoryConfigFileName,
        );
        log("Repository config received.");
        log("Generating table row...");
        log("'ignore': ${repositoryConfig.ignore}");

        if (repositoryConfig.ignore)
          log("Skipping...");
        else
          result += _getTableRow(repositoryConfig: repositoryConfig);
      } on RepositoryConfigFileError catch (e) {
        log("Error getting repository config: ${e.message}.");
        if (e.fileNotFound)
          log("Assuming '${repository.name}' is not a package.");
        log("Skipping...");
      }

      unIndentLog();
    }
    if (result.isNotEmpty) result = await this._getTableHeader() + result;

    unIndentLog();
    log("Done generating table for repositories.", positive: true);
    return result;
  }

  String _getTableHeader() {
    log("Generating table header...");
    indentLog();
    String result = "";

    result += "# $markdownTableName\n";
    result += "| Name | Release | Description | Maintainer |\n";
    result += "| --- | --- | --- | --- |\n";

    unIndentLog();
    log("Done generating table header...", positive: true);
    return result;
  }

  String _getTableRow({@required RepositoryConfig repositoryConfig}) {
    log("Generating table row...");
    indentLog();

    String result = "| ";

    result +=
        "[**${repositoryConfig.packageName}**](${this._git.organization.htmlUrl}/${repositoryConfig.repositoryName ?? repositoryConfig.packageName}) | ";
    result +=
        "[![Pub](https://img.shields.io/pub/v/${repositoryConfig.packageName}.svg)](https://pub.dartlang.org/packages/${repositoryConfig.packageName}) | ";
    result +=
        (repositoryConfig.packageDescription ?? "NO DESCRIPTION PROVIDED") +
            " | ";
    if (repositoryConfig.maintainerUsername != null) {
      result +=
          "[${repositoryConfig.maintainerName ?? repositoryConfig.maintainerUsername}]";
      result += "(https://github.com/${repositoryConfig.maintainerUsername})";
    } else {
      result += repositoryConfig.maintainerName ?? "NO MAINTAINER PROVIDED";
    }

    result += "\n";

    unIndentLog();
    log("Done generating table row...", positive: true);
    return result;
  }

  Future<String> getHeaderText() async {
    await initialize();
    return await this._git.getFileFromRepositoryByName(this.mainRepositoryName,
        fileName: this.headerTextFileName);
  }

  void uploadReadmeToRepository({
    @required String contents,
    @required String accessToken,
  }) async {
    // GitHub.GitHub authenticatedClient = new GitHub.GitHub(
    //     auth: new GitHub.Authentication.withToken(accessToken));
    // GitHub.Repository repository = await authenticatedClient.repositories
    //     .getRepository(new GitHub.RepositorySlug(
    //         this.organizationName, this.mainRepositoryName));
    // repository.
  }
}
