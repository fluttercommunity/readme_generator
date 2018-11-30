import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:github/server.dart' as GitHub;
import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:readme_generator/repository_config.dart';
import 'package:readme_generator/github_tools.dart';
import 'package:yaml/yaml.dart' as YAML;

class ReadmeGeneratorUploadError extends Error {
  ReadmeGeneratorUploadError(this.response) {
    switch (response.statusCode) {
      case (200):
        this.message = "Nothing went wrong. Exception accidentally thrown.";
        break;
      default:
        this.message = "${response.reasonPhrase}";
    }
  }

  final Response response;
  String message;

  @override
  String toString() => "ReadmeGeneratorUploadError: status code ${response.statusCode} - '$message'";
}

class ReadmeGeneratorConfig {
  ReadmeGeneratorConfig({
    @required this.organizationName,
    @required this.mainRepositoryName,
    @required this.mainRepositoryBranch,
    @required this.repositoryConfigFileName,
    @required this.markdownTableName,
    @required this.readmeFileName,
    @required this.resourcesRepositoryBranch,
    @required this.headerTextFileName,
    @required this.headerReplaceKeyword,
    @required this.committerName,
    @required this.committerEmail,
    @required this.commitComment,
  });

  final String organizationName;
  final String mainRepositoryName;
  final String mainRepositoryBranch;
  final String repositoryConfigFileName;
  final String markdownTableName;
  final String readmeFileName;
  final String resourcesRepositoryBranch;
  final String headerTextFileName;
  final String headerReplaceKeyword;
  final String committerName;
  final String committerEmail;
  final String commitComment;

  factory ReadmeGeneratorConfig.fromYAML(YAML.YamlMap config) {
    return ReadmeGeneratorConfig(
      organizationName: config["organization_name"],
      mainRepositoryName: config["main_repository_name"],
      mainRepositoryBranch: config["main_repository_branch"] ?? "master",
      repositoryConfigFileName:
          config["repository_config_file_name"] ?? "pubspec.yaml",
      markdownTableName: config["markdown_table_name"],
      readmeFileName: config["readme_file_name"] ?? "README.md",
      resourcesRepositoryBranch:
          config["resources_repository_branch"] ?? "master",
      headerTextFileName: config["header_text_file_name"],
      headerReplaceKeyword: config["header_replace_keyword"],
      committerName: config["committer_name"],
      committerEmail: config["committer_email"],
      commitComment: config["commit_comment"] ?? "Updated README.",
    );
  }
}

class ReadmeGenerator {
  ReadmeGenerator(this.config);

  final ReadmeGeneratorConfig config;

  bool _log = false;
  int _logLevel = 0;

  GitHubTools _git;

  factory ReadmeGenerator.fromYAML(YAML.YamlMap config) {
    return new ReadmeGenerator(ReadmeGeneratorConfig.fromYAML(config));
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
      await GitHubTools.fromOrganizationName(this.config.organizationName);

  Future<String> generateReadme() async {
    log("Generating readme...");
    indentLog();
    await initialize();
    String headerText = await this.getHeaderText();
    String packageTable = await this.generateTable();
    unIndentLog();
    log("Done generating readme.", positive: true);
    return headerText.replaceFirst(
        this.config.headerReplaceKeyword, packageTable);
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
    log("(Repository config file name: '${this.config.repositoryConfigFileName}')");
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
          configFileName: this.config.repositoryConfigFileName,
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

    if (this.config.markdownTableName != null)
      result += "# ${this.config.markdownTableName}\n";
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
    return await this._git.getFileFromRepositoryByName(
          this.config.mainRepositoryName,
          fileName: this.config.headerTextFileName,
          branch: this.config.resourcesRepositoryBranch,
        );
  }

  Future<Response> uploadReadmeToRepository({
    @required String content,
    @required String authorizationToken,
  }) async {
    await initialize();
    GitHub.Repository repository =
        await this._git.getRepository(this.config.mainRepositoryName);
    final String readmeFileUrl =
        "https://api.github.com/repos/${repository.fullName}/contents/${this.config.readmeFileName}";
    final Response readmeFileInfoRes = await this
        ._git
        .client
        .client
        .get("$readmeFileUrl?ref=${this.config.mainRepositoryBranch}");
    final Map<String, dynamic> readmeFileInfo =
        json.decode(readmeFileInfoRes.body);

    String readmeFileSha;

    if (readmeFileInfo.containsKey("sha")) {
      readmeFileSha = readmeFileInfo["sha"];
    } else {
      readmeFileSha = sha1.convert(utf8.encode(content)).toString();
    }

    final String encodedContent = base64.encode(utf8.encode(content));

    final Response res = await this
        ._git
        .client
        .client
        .put(readmeFileUrl, headers: <String, String>{
      "Authorization": authorizationToken,
      "Accept": "application/vnd.github.v3.full+json-X POST",
    }, body: """
{
  "message": "${this.config.commitComment} (${new DateTime.now().toUtc()} UTC)",
  "committer": {
    "name": "${this.config.committerName}",
    "email": "${this.config.committerEmail}"
  },
  "content": "$encodedContent",
  "sha": "$readmeFileSha",
  "branch": "${this.config.mainRepositoryBranch}"
}
      """);

    if (res.statusCode != 200) {
      throw new ReadmeGeneratorUploadError(res);
    }
    final Map<String, dynamic> responseData = json.decode(res.body);
    log("Uploaded! URL: ${responseData["content"]["html_url"]}");
    return res;
  }
}
