import 'dart:async';
import 'dart:convert' as Convert;

import 'package:github/server.dart' as GitHub;
import 'package:http/http.dart' as Http;
import 'package:meta/meta.dart';

class GitHubTools {
  GitHubTools({
    @required this.organization,
  }) : this.client = new GitHub.GitHub();

  final GitHub.GitHub client;
  final GitHub.Organization organization;

  static Future<GitHubTools> fromOrganizationName(
          String organizationName) async =>
      new GitHubTools(
        organization:
            await new GitHub.GitHub().organizations.get(organizationName),
      );

  static Future<GitHubTools> fromRepository(
      GitHub.Repository repository) async {
    GitHub.GitHub temporaryClient = new GitHub.GitHub();
    String organizationName = repository.owner.login;
    GitHub.Organization organization =
        await temporaryClient.organizations.get(organizationName);
    return new GitHubTools(organization: organization);
  }

  Future<GitHub.Repository> getRepository(String repositoryName) {
    return this.client.repositories.getRepository(
        new GitHub.RepositorySlug(this.organization.login, repositoryName));
  }

  static Future<String> getFile(String url, [String fallBackString]) async {
    Http.Response response = await Http.get(url);
    String result = new String.fromCharCodes(response.bodyBytes);

    if (result.startsWith("404") && fallBackString != null)
      return fallBackString;

    return result;
  }

  Future<String> getFileFromRepository(
    GitHub.Repository repository, {
    @required String fileName,
    String branch: "master",
    String fallBackString,
  }) =>
      getFile(
        "https://raw.githubusercontent.com/${repository.fullName}/$branch/$fileName",
        fallBackString,
      );

  Future<String> getFileFromRepositoryByName(
    String repositoryName, {
    @required String fileName,
    String branch: "master",
    String fallBackString,
  }) async {
    GitHub.Repository repository = await this.client.repositories.getRepository(
        new GitHub.RepositorySlug(this.organization.login, repositoryName));

    return await this.getFileFromRepository(
      repository,
      fileName: fileName,
      fallBackString: fallBackString,
      branch: branch,
    );
  }

  Future<List<GitHub.Repository>> getAllRepositories() async {
    String response = await getFile(
        "https://api.github.com/users/${this.organization.login}/repos");
    List<Map> jsonResponse = List.castFrom<dynamic, Map>(Convert.json.decode(response)).toList();
    List<GitHub.Repository> result = jsonResponse
        .map((jsonRepository) => GitHub.Repository.fromJSON(jsonRepository))
        .toList();

    return result;
  }
}
