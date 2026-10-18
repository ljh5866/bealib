import 'package:flutter_modular/flutter_modular.dart';
import 'package:bealib/pages/about/about_page.dart';

final aboutModule = createModule(
  path: '/about',
  register: (c) {
    c.route('/', child: (context, state) => const AboutPage());
  },
);
