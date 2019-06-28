import 'package:angel_container_generator/angel_container_generator.dart';
import 'package:angel_container/angel_container.dart' as angel_container;
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'action.dart';

typedef SetState = void Function();

abstract class Module<S> {
  static angel_container.Container _container;

  static angel_container.Container makeContainer() {
    const reflector = GeneratedReflector();
    final container = angel_container.Container(reflector);
    _container = container;
    return container;
  }

  static State<W> createAppState<W extends StatefulWidget, M extends Module>(
      State<W> Function(M ayanamiState) builder) {
    final instance = _container.make(M);
    instance._appState = builder(instance);
    return instance._appState;
  }

  S get state;

  @protected
  final Subject<Action> action$ = PublishSubject();

  @protected
  final Subject<Action> state$ = PublishSubject();

  State _appState;

  S setState(SetState setter) {
    // ignore: invalid_use_of_protected_member
    _appState.setState(setter);
    return state;
  }

  Future<void> dispose() async {
    await action$.close();
    await state$.close();
  }
}
