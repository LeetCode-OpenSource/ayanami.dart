import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:rxdart/rxdart.dart';

import 'src/annotation.dart' as annotation;

const ObservableTypeChecker = TypeChecker.fromRuntime(Observable);
const ModuleAnnotationTypeChecker =
    TypeChecker.fromRuntime(annotation.ModuleAnnotation);
const EpicAnnotationTypeChecker =
    TypeChecker.fromRuntime(annotation.EpicAnnotation);
const ActionAnnotationTypeChecker =
    TypeChecker.fromRuntime(annotation.ActionAnnotation);

Builder moduleBuilder(BuilderOptions options) {
  return LibraryBuilder(ModuleGenerator(), generatedExtension: '.m.dart');
}

class ModuleGenerator extends Generator {
  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final visitor = _Visitor();
    library.element.visitChildren(visitor);
    return visitor.result;
  }
}

class _Visitor extends GeneralizingElementVisitor {
  String result = '';

  String epics = '';

  String actions = '';

  String classFieldName = '';

  @override
  void visitClassElement(ClassElement element) {
    if (element.metadata.any((m) => ModuleAnnotationTypeChecker.isExactlyType(
        m.computeConstantValue().type))) {
      final className = element.name;
      final stateType = element.supertype.typeArguments[0];
      final stateTypeImportPath =
          stateType.element.source.uri.path.replaceAll('lib/', '');
      classFieldName =
          '_${className[0].toLowerCase()}${className.substring(1)}';
      result += '''
import 'package:rxdart/rxdart.dart';
import 'package:ayanami/ayanami.dart';
import 'package:flutter/widgets.dart';
import 'package:$stateTypeImportPath';
import '${element.source.uri.pathSegments.last}';
export '${element.source.uri.pathSegments.last}';

class ${className}Connector {
  static State<W> createAppState<W extends StatefulWidget>(
      State<W> Function(${className}Connector connector) builder) {
    return Module.createAppState<W, $className>((state) => builder(${className}Connector(state)));
  }

  final $className $classFieldName;

  $stateType useState() {
    return $classFieldName.state;
  }

      ''';
      element.visitChildren(this);
      result += '''
 
    ${className}Connector(this.$classFieldName) {
      $actions;
      Observable.merge([$epics]).listen((_) {});
    }
}
      ''';
    }
  }

  @override
  void visitFieldElement(FieldElement element) {
    if (element.metadata.any((m) => ActionAnnotationTypeChecker.isExactlyType(
        m.computeConstantValue().type))) {
      final name = element.name;
      final fieldType = element.type;
      if (ObservableTypeChecker.isExactlyType(fieldType)) {
        String payloadType;
        if (fieldType is ParameterizedType) {
          final type = fieldType.typeArguments[0];
          final typeString = '$type';
          if (!type.isVoid && typeString != 'Null') {
            payloadType = '$type';
          }
        } else {
          payloadType = 'dynamic';
        }
        final methodCodes = payloadType == null
            ? 'void $name() { $classFieldName.action\$.add(Action(\'$name\', null)); }'
            : 'void $name($payloadType payload) { $classFieldName.action\$.add(Action(\'$name\', payload)); }';
        result += '\n$methodCodes\n';

        actions +=
            '$classFieldName.$name = $classFieldName.action\$.where((action) => action.type == \'$name\')';
      }
    }
  }

  @override
  void visitMethodElement(MethodElement element) {
    if (element.metadata.any((m) => EpicAnnotationTypeChecker.isExactlyType(
        m.computeConstantValue().type))) {
      final name = element.name;
      String payloadType;
      final action = element.parameters[0];
      if (ObservableTypeChecker.isExactlyType(action.type)) {
        final actionType = action.type;
        if (actionType is ParameterizedType) {
          final type = actionType.typeArguments[0];
          final typeString = '$type';
          if (!type.isVoid && typeString != 'Null') {
            payloadType = '$type';
          }
        } else {
          payloadType = 'dynamic';
        }
        final methodCodes = payloadType == null
            ? 'void $name () { $classFieldName.action\$.add(Action(\'$name\', null)); }'
            : 'void $name ($payloadType payload) { $classFieldName.action\$.add(Action(\'$name\', payload)); }';
        result += methodCodes;

        epics +=
            '$classFieldName.$name($classFieldName.action\$.where((action) => action.type == \'$name\').map((action) => action.payload)),';
      } else {
        throw ModuleGenerateError('first parameter of epic must be Observable');
      }
    }
  }
}

class ModuleGenerateError extends Error {
  ModuleGenerateError(this.message) : super();

  final String message;

  @override
  String toString() {
    return message;
  }
}
