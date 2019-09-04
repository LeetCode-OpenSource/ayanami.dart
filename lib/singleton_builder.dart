import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/annotation.dart' as annotation;

const SingletonAnnotationTypeChecker =
    TypeChecker.fromRuntime(annotation.SingletonContainedReflectable);

Builder singletonBuilder(BuilderOptions options) {
  final content = StringBuffer();
  final imports = StringBuffer();
  imports.write(
      'import \'package:angel_container/angel_container.dart\' as angel_container;\n');
  content.write('''
    void setupSingleton(angel_container.Container container) {
  ''');
  return _SingletonBuilder(imports, content);
}

class _SingletonBuilder extends Builder {
  _SingletonBuilder(this.imports, this.content);

  static int suffix = 0;

  final StringBuffer imports;
  final StringBuffer content;

  @override
  Map<String, List<String>> get buildExtensions => const {
        '.dart': ['.singleton.dart'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    final libraries = await resolver.libraries.toList();
    final inputLib = await buildStep.inputLibrary;
    libraries
        .where((lib) =>
            lib.source.uri.scheme == inputLib.source.uri.scheme &&
            lib.source.uri.pathSegments.first ==
                inputLib.source.uri.pathSegments.first)
        .forEach((lib) {
      final genterated = _generate(LibraryReader(lib));
      if (genterated) {
        imports.write(
            'import \'${lib.source.uri.toString()}\' as prefix$suffix;\n');
      }
    });
    content.write('}');
    var inputId = buildStep.inputId;
    var outputId = inputId.changeExtension('.singleton.dart');
    await buildStep.writeAsString(
        outputId, imports.toString() + '\n' + content.toString());
  }

  bool _generate(LibraryReader library) {
    var generated = false;
    for (final classElement in library.classes) {
      if (SingletonAnnotationTypeChecker.hasAnnotationOf(classElement)) {
        final className = classElement.name;
        generated = true;
        suffix++;
        content.write('''
          final prefix$suffix.$className instance$suffix = container.make(prefix$suffix.$className);
          container.registerSingleton(instance$suffix, as: prefix$suffix.$className);
        ''');
      }
    }
    return generated;
  }
}
