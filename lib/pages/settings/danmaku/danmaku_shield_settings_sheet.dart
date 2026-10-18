import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:bealib/bean/dialog/material_bottom_sheet.dart';
import 'package:bealib/pages/my/my_controller.dart';
import 'package:bealib/pages/settings/danmaku/danmaku_shield_editor.dart';

class DanmakuShieldSettingsSheet extends StatelessWidget {
  const DanmakuShieldSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            MaterialBottomSheetHeader(
              title: '屏蔽规则',
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: DanmakuShieldEditor(controller: inject<MyController>()),
            ),
          ],
        ),
      );
}
