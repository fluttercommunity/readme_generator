import 'package:github/server.dart' as GitHub;
import 'package:meta/meta.dart';

class IgnoredRepositories {
  IgnoredRepositories({@required this.found, @required this.notFound});

  final List<GitHub.Repository> found;
  final List<String> notFound;
}