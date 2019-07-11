import 'package:angel_container_generator/angel_container_generator.dart';
import 'package:angel_container/angel_container.dart' as angel_container;
import 'package:flutter/widgets.dart' as widget;
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

  static widget.State<W>
      createAppState<W extends widget.StatefulWidget, M extends Module>(
          widget.State<W> Function(M ayanamiState) builder,
          {bool singleton = true}) {
    final hasSingleton = _container.has(M);
    final instance = _container.make(M);
    if (!hasSingleton && singleton) {
      _container.registerSingleton(instance, as: M);
    }
    instance._appState = builder(instance);
    return instance._appState;
  }

  S get state;

  final Subject<Action> action$ = PublishSubject();

  final Subject<Action> state$ = PublishSubject();

  widget.State _appState;

  widget.State get appState {
    return _appState;
  }

  Observable<S> setState(SetState setter) {
    return Observable.fromFuture(widget.WidgetsBinding.instance.endOfFrame)
        .doOnData((_) {
      if (_appState.mounted) {
        // ignore: invalid_use_of_protected_member
        _appState.setState(setter);
      }
    }).map((_) => state);
  }

  Future<Null> dispose() async {
    await action$.close();
    await state$.close();
  }
}
