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
    final visitor = _Visitor(library);
    library.element.visitChildren(visitor);
    return visitor.result;
  }
}

class _Visitor extends GeneralizingElementVisitor {
  _Visitor(this.library);

  String result = '';

  final List<EpicMeta> epics = [];

  String actions = '';

  String classFieldName = '';

  final LibraryReader library;

  @override
  void visitClassElement(ClassElement element) {
    if (element.metadata.any((m) => ModuleAnnotationTypeChecker.isExactlyType(
        m.computeConstantValue().type))) {
      final className = element.name;
      final stateType = element.supertype.typeArguments[0];
      classFieldName =
          '_${className[0].toLowerCase()}${className.substring(1)}';
      final stateTypeImportPath =
          stateType.element.source.uri.pathSegments.last;
      result += '''
part of \'$stateTypeImportPath\';

class ${className}Connector {
  static ${className}Connector _instance;

  static State<W> createAppState<W extends StatefulWidget>(
      State<W> Function(${className}Connector connector) builder, {bool singleton = true}) {
        if (singleton && _instance != null) {
          return Module.createAppState<W, $className>((state) => builder(_instance), singleton: singleton);
        }
    return Module.createAppState<W, $className>((state) {
      final instance = ${className}Connector(state);
      if (singleton) {
        _instance = instance;
      }
      return builder(instance);
    }, singleton: singleton);
  }

  final $className $classFieldName;

  $stateType useState() {
    return $classFieldName.state;
  }

      ''';
      element.visitChildren(this);
      final listenedEpics = epics
          .map((meta) =>
              '$classFieldName.${meta.actionName}(${meta.action}.map((action) => action.payload))')
          .join(',\n');

      final addActionsMap = epics
          .map((meta) =>
              '$classFieldName.actions[$classFieldName.${meta.actionName}] = r\'${meta.actionName}\';')
          .join('\n');
      result += '''

    ${className}Connector(this.$classFieldName) {
      $actions;

      $addActionsMap

      Observable.merge([$listenedEpics]).listen((action) {
        if (action.type == DispatchSymbol) {
          action.module.action\$.add(action.dispatchAction);
        }
      });
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
            ? 'void $name() { $classFieldName.action\$.add(AyanamiAction(r\'$name\', null)); }'
            : 'void $name($payloadType payload) { $classFieldName.action\$.add(AyanamiAction(\'$name\', payload)); }';
        result += '\n$methodCodes\n';

        actions += '''
              $classFieldName.$name = $classFieldName.action\$
                .where((action) => action.type == r\'$name\')
                .map((action) => action.payload as ${payloadType == null ? Null : payloadType})
            ''';
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
            ? 'void $name () { $classFieldName.action\$.add(AyanamiAction(\'$name\', null)); }'
            : 'void $name ($payloadType payload) { $classFieldName.action\$.add(AyanamiAction(\'$name\', payload)); }';
        result += methodCodes;
        final meta = EpicMeta(
            '$classFieldName.action\$.where((action) => action.type == r\'$name\')',
            name,
            payloadType);
        epics.add(meta);
      } else {
        throw ModuleGenerateError('first parameter of epic must be Observable');
      }
    }
  }
}

class EpicMeta {
  EpicMeta(
    this.action,
    this.actionName,
    this.payloadType,
  );

  final String action;

  final String actionName;

  final String payloadType;
}

class ModuleGenerateError extends Error {
  ModuleGenerateError(this.message) : super();

  final String message;

  @override
  String toString() {
    return message;
  }
}
