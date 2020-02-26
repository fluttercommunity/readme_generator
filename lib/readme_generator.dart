import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:github/server.dart' as github;
import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:readme_generator/repository_config.dart';
import 'package:readme_generator/github_tools.dart';
import 'package:yaml/yaml.dart' as yaml;

class ReadmeGeneratorUploadError extends Error {
  ReadmeGeneratorUploadError(this.response) {
    switch (response.statusCode) {
      case 200:
        message = 'Nothing went wrong. Exception accidentally thrown.';
        break;
      default:
        message = '${response.reasonPhrase}';
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

  factory ReadmeGeneratorConfig.fromYAML(yaml.YamlMap config) {
    return ReadmeGeneratorConfig(
      organizationName: config['organization_name'],
      mainRepositoryName: config['main_repository_name'],
      mainRepositoryBranch: config['main_repository_branch'] ?? 'master',
      repositoryConfigFileName: config['repository_config_file_name'] ?? 'pubspec.yaml',
      markdownTableName: config['markdown_table_name'],
      readmeFileName: config['readme_file_name'] ?? 'README.md',
      resourcesRepositoryBranch: config['resources_repository_branch'] ?? 'master',
      headerTextFileName: config['header_text_file_name'],
      headerReplaceKeyword: config['header_replace_keyword'],
      committerName: config['committer_name'],
      committerEmail: config['committer_email'],
      commitComment: config['commit_comment'] ?? 'Updated README.',
    );
  }
}

class ReadmeGenerator {
  ReadmeGenerator(this.config);

  final ReadmeGeneratorConfig config;

  bool _log = false;
  int _logLevel = 0;

  GitHubTools _git;

  factory ReadmeGenerator.fromYAML(yaml.YamlMap config) {
    return ReadmeGenerator(ReadmeGeneratorConfig.fromYAML(config));
  }

  void enableLogging() => _log = true;

  void disableLogging() => _log = false;

  void indentLog() => _logLevel += 1;

  void unIndentLog() => _logLevel -= (_logLevel <= 0) ? 0 : 1;

  void log(
    String message, {
    bool error = false,
    bool warn = false,
    bool positive = false,
  }) {
    if (_log) {
      final text = (' ' * (_logLevel * 2)) + message;
      print(text);
    }
  }

  Future<void> initialize() async {
    return _git ??= await GitHubTools.fromOrganizationName(config.organizationName);
  }

  Future<String> generateReadme() async {
    log('Generating readme...');
    indentLog();

    await initialize();

    final headerText = await getHeaderText();
    final packageTable = await generateTable();

    unIndentLog();

    log('Done generating readme.', positive: true);

    return headerText.replaceFirst(config.headerReplaceKeyword, packageTable);
  }

  Future<String> generateTable() async {
    log('Generating table...');
    indentLog();

    await initialize();

    final repositoriesToParse = await _git.getAllRepositories();

    final result = await _generateTableForRepositories(repositoriesToParse);

    unIndentLog();

    log('Done generating table.', positive: true);

    return result;
  }

  Future<String> _generateTableForRepositories(List<github.Repository> repositories) async {
    log("Generating table for repositories\n\t${repositories.map<String>((repository) => repository.name).join(', ')}...");
    log("(Repository config file name: '${config.repositoryConfigFileName}')");
    indentLog();

    var result = '';

    for (final repository in repositories) {
      log('- ${repository.name}');
      indentLog();
      log('Getting repository config...');
      try {
        final repositoryConfig = await RepositoryConfig.fromRepository(
          repository,
          configFileName: config.repositoryConfigFileName,
        );
        log('Repository config received.');
        log('Generating table row...');
        log("'ignore': ${repositoryConfig.ignore}");

        if (repositoryConfig.ignore) {
          log('Skipping...');
        } else {
          result += _getTableRow(repositoryConfig: repositoryConfig);
        }
      } on RepositoryConfigFileError catch (e) {
        log('Error getting repository config: ${e.message}.');
        if (e.fileNotFound) {
          log("Assuming '${repository.name}' is not a package.");
        }
        log('Skipping...');
      }

      unIndentLog();
    }
    if (result.isNotEmpty) {
      result = _getTableHeader() + result;
    }

    unIndentLog();
    log('Done generating table for repositories.', positive: true);
    return result;
  }

  String _getTableHeader() {
    log('Generating table header...');
    indentLog();
    var result = '';

    if (config.markdownTableName != null) {
      result += '# ${config.markdownTableName}\n';
    }
    result += '| Name | Release | Description | Maintainer |\n';
    result += '| --- | --- | --- | --- |\n';

    unIndentLog();
    log('Done generating table header...', positive: true);
    return result;
  }

  String _getTableRow({@required RepositoryConfig repositoryConfig}) {
    log('Generating table row...');
    indentLog();

    var result = '| ';

    result +=
        '[**${repositoryConfig.packageName}**](${_git.organization.htmlUrl}/${repositoryConfig.repositoryName ?? repositoryConfig.packageName}) | ';
    result +=
        '[![Pub](https://img.shields.io/pub/v/${repositoryConfig.packageName}.svg)](https://pub.dartlang.org/packages/${repositoryConfig.packageName}) | ';
    result += '${repositoryConfig.packageDescriptionEscaped ?? 'NO DESCRIPTION PROVIDED'} | ';
    if (repositoryConfig.maintainerUsername != null) {
      result += '[${repositoryConfig.maintainerName ?? repositoryConfig.maintainerUsername}]';
      result += '(https://github.com/${repositoryConfig.maintainerUsername})';
    } else {
      result += repositoryConfig.maintainerName ?? 'NO MAINTAINER PROVIDED';
    }

    result += '\n';

    unIndentLog();
    log('Done generating table row...', positive: true);
    return result;
  }

  Future<String> getHeaderText() async {
    await initialize();
    return _git.getFileFromRepositoryByName(
      config.mainRepositoryName,
      fileName: config.headerTextFileName,
      branch: config.resourcesRepositoryBranch,
    );
  }

  Future<Response> uploadReadmeToRepository({
    @required String content,
    @required String authorizationToken,
  }) async {
    await initialize();
    final repository = await _git.getRepository(config.mainRepositoryName);
    final readmeFileUrl = 'https://api.github.com/repos/${repository.fullName}/contents/${config.readmeFileName}';
    final readmeFileInfoRes = await _git.client.client.get('$readmeFileUrl?ref=${config.mainRepositoryBranch}');
    final readmeFileInfo = json.decode(readmeFileInfoRes.body);

    final readmeFileSha = readmeFileInfo['sha'] ?? sha1.convert(utf8.encode(content)).toString();

    final encodedContent = base64.encode(utf8.encode(content));

    final res = await _git.client.client.put(
      readmeFileUrl,
      headers: <String, String>{
        'Authorization': authorizationToken,
        'Accept': 'application/vnd.github.v3.full+json-X POST',
      },
      body: '''
{
  "message": "${config.commitComment} (${DateTime.now().toUtc()} UTC)",
  "committer": {
    "name": "${config.committerName}",
    "email": "${config.committerEmail}"
  },
  "content": "$encodedContent",
  "sha": "$readmeFileSha",
  "branch": "${config.mainRepositoryBranch}"
}
      ''',
    );

    if (res.statusCode != 200) {
      throw ReadmeGeneratorUploadError(res);
    }
    final responseData = json.decode(res.body) as Map<String, dynamic>;
    log("Uploaded! URL: ${responseData["content"]["html_url"]}");
    return res;
  }
}
