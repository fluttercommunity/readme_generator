import 'dart:async';
import 'dart:convert' as convert;

import 'package:github/server.dart' as github;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

class GitHubTools {
  GitHubTools({
    @required this.organization,
  }) : client = github.GitHub();

  final github.GitHub client;
  final github.Organization organization;

  static Future<GitHubTools> fromOrganizationName(String organizationName) async => GitHubTools(
        organization: await github.GitHub().organizations.get(organizationName),
      );

  static Future<GitHubTools> fromRepository(github.Repository repository) async {
    final temporaryClient = github.GitHub();
    final organizationName = repository.owner.login;
    final organization = await temporaryClient.organizations.get(organizationName);
    return GitHubTools(organization: organization);
  }

  Future<github.Repository> getRepository(String repositoryName) {
    return client.repositories.getRepository(github.RepositorySlug(organization.login, repositoryName));
  }

  static Future<String> getFile(String url, [String fallBackString]) async {
    final response = await http.get(url);
    final result = String.fromCharCodes(response.bodyBytes);

    if (result.startsWith('404') && fallBackString != null) {
      return fallBackString;
    }

    return result;
  }

  Future<String> getFileFromRepository(
    github.Repository repository, {
    @required String fileName,
    String branch = 'master',
    String fallBackString,
  }) =>
      getFile(
        'https://raw.githubusercontent.com/${repository.fullName}/$branch/$fileName',
        fallBackString,
      );

  Future<String> getFileFromRepositoryByName(
    String repositoryName, {
    @required String fileName,
    String branch = 'master',
    String fallBackString,
  }) async {
    final repository =
        await client.repositories.getRepository(github.RepositorySlug(organization.login, repositoryName));

    return getFileFromRepository(
      repository,
      fileName: fileName,
      fallBackString: fallBackString,
      branch: branch,
    );
  }

  Future<List<github.Repository>> getAllRepositories() async {
    final response = await getFile('https://api.github.com/users/${organization.login}/repos');
    final jsonResponse = List.castFrom<dynamic, Map>(convert.json.decode(response)).toList();
    // ignore: unnecessary_lambdas
    final result = jsonResponse.map((jsonRepository) => github.Repository.fromJSON(jsonRepository)).toList();

    return result;
  }
}
