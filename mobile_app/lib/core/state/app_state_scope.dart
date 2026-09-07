import 'package:flutter/material.dart';

import 'app_state.dart';

class OracleAppStateScope extends InheritedNotifier<OracleAppState> {
  const OracleAppStateScope({
    super.key,
    required OracleAppState state,
    required super.child,
  }) : super(notifier: state);

  static OracleAppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<OracleAppStateScope>();
    assert(scope != null, 'OracleAppStateScope is not found in the widget tree.');
    return scope!.notifier!;
  }
}

class OracleStateBuilder extends StatelessWidget {
  const OracleStateBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, OracleAppState state) builder;

  @override
  Widget build(BuildContext context) {
    final state = OracleAppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => builder(context, state),
    );
  }
}
