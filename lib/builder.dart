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
import 'package:angel_container_generator/angel_container_generator.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/widgets.dart';
import 'package:ayanami/ayanami.dart';
import 'package:$stateTypeImportPath';
import '${element.source.uri.pathSegments.last}';

@contained
class ${className}Dispatcher {
  final $className $classFieldName;

  $className get ${classFieldName.substring(1)} {
    return $classFieldName;
  }

      ''';
      element.visitChildren(this);
      result += '''
 
    ${className}Dispatcher(this.$classFieldName) {
      Observable.merge([$epics]).listen((_) {});
    }
}

@contained
class ${className}Widget extends StatefulWidget {
  ${className}Widget(this.dispatcher);

  final ${className}Dispatcher dispatcher;

  @override
  HomeState createState() {
    final state = HomeState(dispatcher);
    dispatcher.homeModule.state = state;
    return state;
  }
}
      ''';
    }
  }

  @override
  void visitMethodElement(MethodElement element) {
    if (element.metadata.any((m) => m.element.name == 'epic')) {
      final name = element.name;
      String payloadType;
      final action = element.parameters[0];
      if (ObservableTypeChecker.isExactlyType(action.type)) {
        final actionType = action.type;
        if (actionType is ParameterizedType) {
          final type = actionType.typeArguments[0];
          if (!type.isVoid) {
            payloadType = '$type';
          }
        } else {
          payloadType = 'dynamic';
        }
        final methodCodes = payloadType == null || payloadType == 'Null'
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
