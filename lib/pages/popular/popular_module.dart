import 'package:flutter_modular/flutter_modular.dart';
import 'package:bealib/pages/popular/popular_page.dart';
import 'package:bealib/pages/popular/popular_controller.dart';

final popularModule = createModule(
  path: '/popular',
  register: (c) {
    c.route(
      '/',
      transition: TransitionType.none,
      child: (context, state) => PopularPage(
        controller: inject<PopularController>(),
      ),
    );
  },
);
