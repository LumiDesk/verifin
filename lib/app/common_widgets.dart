/// 通用组件库（跨页面复用，组件清单见 docs/dev/components.md）。
/// 组件按域放在 part 文件里，新增组件进对应域、勿再堆回本文件；
/// 调用方一律 `import 'common_widgets.dart'`，导入路径不变。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_localizations.dart';
import 'account_icon_assets.dart';
import 'app_theme.dart';
import 'category_tree.dart';
import 'credit_card.dart';
import 'icon_catalog.dart';
import 'model_lookup.dart';
import 'ledger_math.dart';
import 'models.dart';

part 'common_widgets_display.dart';
part 'common_widgets_forms.dart';
part 'common_widgets_panels.dart';
part 'common_widgets_scaffold.dart';
part 'common_widgets_transactions.dart';
