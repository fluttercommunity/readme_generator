import 'dart:async';

import 'package:readme_generator/community_config.dart';
import 'package:github/server.dart' as GitHub;
import 'package:meta/meta.dart';
import 'package:readme_generator/github_tools.dart';

class ReadmeGenerator {
  ReadmeGenerator({
    @required this.organizationName,
    @required this.mainRepositoryName,
    @required this.repositoryConfigFileName,
    @required this.markdownTableName,
    @required this.headerTextFileName,
  });

  final String organizationName;
  final String mainRepositoryName;
  final String repositoryConfigFileName;
  final String markdownTableName;
  final String headerTextFileName;

  GitHubTools _git;

  factory ReadmeGenerator.fromJSON(Map<String, dynamic> config) {
    return new ReadmeGenerator(
      organizationName: config["organization_name"],
      mainRepositoryName: config["main_repository_name"],
      repositoryConfigFileName: config["repository_config_file_name"],
      markdownTableName: config["markdown_table_name"],
      headerTextFileName: config["header_text_file_name"],
    );
  }

  Future<String> generateReadme() async {
    this._git ??= await GitHubTools.fromOrganizationName(this.organizationName);
    String headerText = await this.getHeaderText();
    String packageTable = await this.generateTable();

    return headerText + "\n" + packageTable;
  }

  Future<String> generateTable() async {
    this._git ??= await GitHubTools.fromOrganizationName(this.organizationName);
    List<GitHub.Repository> repositoriesToParse =
        await this._git.getAllRepositories();

    return await this._generateTableForRepositories(repositoriesToParse);
  }

  Future<String> _generateTableForRepositories(
      List<GitHub.Repository> repositories) async {
    String result = "";

    for (GitHub.Repository repository in repositories) {
      try {
        RepositoryConfig repositoryConfig =
            await RepositoryConfig.fromRepository(repository,
                configFileName: this.repositoryConfigFileName);

        if (repositoryConfig.isPackage)
          result += _getTableRow(repositoryConfig: repositoryConfig);
      } on RepositoryConfigFileError catch (e) {
        print(
            "Error while getting repository config for '${repository.fullName}': ${e.message}");
        print("Skipping...");
      }
    }

    if (result.isNotEmpty) result = await this._getTableHeader() + result;

    return result;
  }

  String _getTableHeader() {
    String result = "";

    result += "## $markdownTableName\n";
    result += "| Name | Release | Description | Maintainer |\n";
    result += "| --- | --- | --- | --- |\n";

    return result;
  }

  String _getTableRow({@required RepositoryConfig repositoryConfig}) {
    String result = "| ";

    result +=
        "[**${repositoryConfig.packageName}**](${this._git.organization.htmlUrl}/${repositoryConfig.packageName}) | ";
    result +=
        "[![Pub](https://img.shields.io/pub/v/${repositoryConfig.pubPackageName ?? repositoryConfig.packageName}.svg)](" +
            ((repositoryConfig.pubUrl) ??
                "(https://pub.dartlang.org/packages/${repositoryConfig.pubPackageName ?? repositoryConfig.packageName}") +
            ") | ";
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

    return result;
  }

  Future<String> getHeaderText() async {
    this._git ??= await GitHubTools.fromOrganizationName(this.organizationName);
    return await this._git.getFileFromRepositoryByName(this.mainRepositoryName,
        fileName: this.headerTextFileName);
  }
}
