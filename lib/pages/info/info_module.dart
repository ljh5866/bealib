import 'package:flutter_modular/flutter_modular.dart';
import 'package:bealib/modules/bangumi/bangumi_item.dart';
import 'package:bealib/pages/info/info_controller.dart';
import 'package:bealib/pages/info/bealib_watch_entry_page.dart';
import 'package:bealib/pages/route_error_page.dart';

final infoModule = createModule(
  path: '/info',
  register: (c) {
    c.route(
      '/',
      provide: (s) => s.add<InfoController>(InfoController.new),
      child: (context, state) {
        final bangumiItem = state.arguments;
        if (bangumiItem is! BangumiItem) {
          return const RouteErrorPage(message: '番组详情参数无效，请返回后重新打开。');
        }
        return BealibWatchEntryPage(bangumiItem: bangumiItem);
      },
    );
  },
);
