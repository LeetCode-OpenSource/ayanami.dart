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

  TestModule registerSingleton<T>({void Function(T instance) getter}) {
    final registered = _container.has(T);

    if (!registered) {
      _container.registerSingleton(_container.make(T));
    }
    if (getter != null) {
      getter(_container.make(T));
    }
    return this;
  }
}
