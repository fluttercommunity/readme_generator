import 'package:github/server.dart' as github;
import 'package:meta/meta.dart';

class IgnoredRepositories {
  IgnoredRepositories({@required this.found, @required this.notFound});

  final List<github.Repository> found;
  final List<String> notFound;
}