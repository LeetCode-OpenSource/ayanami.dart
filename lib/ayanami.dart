library ayanami;

import 'src/annotation.dart';

export 'package:angel_container_generator/angel_container_generator.dart';
export 'package:angel_container/src/container.dart';
export 'src/action.dart';
export 'src/module.dart';

const epic = EpicAnnotation();
const module = ModuleAnnotation();
const action = ActionAnnotation();
const singleton = const SingletonContainedReflectable();
