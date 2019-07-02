import 'package:angel_container/angel_container.dart';

import 'module.dart';

class TestModule {
  TestModule(this._container);

  static TestModule configureTestingModule() {
    return TestModule(Module.makeContainer());
  }

  final Container _container;

  TestModule overrideProvider<T>(Type provide, T override) {
    _container.registerSingleton(override, as: provide);
    return this;
  }

  TestModule registerSingleton(Type T,
      {void Function(dynamic instance) getter}) {
    final registered = _container.has(T);
    final instance = _container.make(T);
    if (!registered) {
      _container.registerSingleton(instance);
    }
    if (getter != null) {
      getter(instance);
    }
    return this;
  }
}
