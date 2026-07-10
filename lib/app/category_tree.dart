// 多级分类（树形结构）的纯函数工具集。
//
// 分类通过 [Category.parentId] 组织成任意层级的树：parentId == null 为顶级，
// 子分类与父分类的 type 始终一致。列表内的相对顺序即为同级排序，
// 这里的所有函数都保持传入列表的顺序，不做额外排序。
//
// 所有遍历都带环检测（visited 集合），即使数据异常也不会死循环。

import 'models.dart';

/// 树中的一个节点，携带其在树中的深度（顶级为 0），用于 UI 缩进展示。
class CategoryNode {
  const CategoryNode({required this.category, required this.depth});

  final Category category;
  final int depth;
}

/// 按 id 建立查找表，便于 O(1) 取父分类。
Map<String, Category> categoryIndex(List<Category> all) {
  return <String, Category>{for (final c in all) c.id: c};
}

/// 指定类型的顶级分类，保持列表顺序。
List<Category> rootCategories(List<Category> all, EntryType type) {
  return all
      .where((c) => c.type == type && c.parentId == null)
      .toList(growable: false);
}

/// 直接子分类（仅一层），保持列表顺序。
List<Category> childrenOf(List<Category> all, String parentId) {
  return all.where((c) => c.parentId == parentId).toList(growable: false);
}

/// 是否有子分类。
bool hasChildren(List<Category> all, String parentId) {
  return all.any((c) => c.parentId == parentId);
}

/// 从直接父分类到顶级的祖先 id 列表（不含自身），由近到远。
///
/// **只沿存在的分类记录向上走**：一旦某个 `parentId` 指向的分类在列表里查不到（孤儿分类），
/// 就在此截断，不把这个「不存在的父 id」计入祖先。否则孤儿分类会把一个查不到的 id 当成
/// 顶级返回，配合 [categoryByIdFrom] 的占位回退渲染出「幽灵同名分类」（见 report_analysis）。
List<String> ancestorIds(List<Category> all, String id) {
  final index = categoryIndex(all);
  final result = <String>[];
  final visited = <String>{id};
  var current = index[id]?.parentId;
  while (current != null &&
      index.containsKey(current) &&
      visited.add(current)) {
    result.add(current);
    current = index[current]?.parentId;
  }
  return result;
}

/// 顶级祖先的 id：自身即顶级（或 `parentId` 悬空的孤儿）时返回自身；交易引用的分类
/// 本身不存在（悬空引用）时也返回该 id 本身——此时由展示层的 [categoryByIdFrom] 归为
/// 「已删除分类」占位，不再冒名成列表首个分类。
String rootIdOf(List<Category> all, String id) {
  final ancestors = ancestorIds(all, id);
  return ancestors.isEmpty ? id : ancestors.last;
}

/// 分类名归一化键：用于「创建/导入分类时判断是否已存在同名分类」，避免仅因大小写、首尾
/// 空白、全半角差异而增殖出重复分类（如「餐饮」与「餐饮 」、「ＡＢＣ」与「abc」）。
/// 这是**去重匹配**用的宽松键，不改变分类真实 `label`（展示仍用原始 label）。
String normalizedCategoryLabel(String label) {
  final buffer = StringBuffer();
  for (final rune in label.runes) {
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      // 全角 ASCII（U+FF01–U+FF5E）→ 对应半角（相差 0xFEE0）。
      buffer.writeCharCode(rune - 0xFEE0);
    } else if (rune == 0x3000) {
      // 全角空格 → 半角空格（随后 trim 掉）。
      buffer.writeCharCode(0x20);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().trim().toLowerCase();
}

/// 所有后代分类 id（任意层级，不含自身），前序遍历顺序。
List<String> descendantIds(List<Category> all, String id) {
  final result = <String>[];
  final visited = <String>{id};
  void walk(String parentId) {
    for (final child in childrenOf(all, parentId)) {
      if (visited.add(child.id)) {
        result.add(child.id);
        walk(child.id);
      }
    }
  }

  walk(id);
  return result;
}

/// [id] 是否为 [ancestorId] 的后代（含相等判断为 false）。用于移动分类时的环检测。
bool isDescendantOf(List<Category> all, String id, String ancestorId) {
  return ancestorIds(all, id).contains(ancestorId);
}

/// 分类深度：顶级为 0，其子级为 1，依次类推。
int depthOf(List<Category> all, String id) {
  return ancestorIds(all, id).length;
}

/// 分类的完整路径标签，如「餐饮 / 咖啡」。找不到分类返回空串。
String pathLabel(List<Category> all, String id, {String separator = ' / '}) {
  final index = categoryIndex(all);
  final self = index[id];
  if (self == null) {
    return '';
  }
  final labels = <String>[self.label];
  for (final ancestorId in ancestorIds(all, id)) {
    final ancestor = index[ancestorId];
    if (ancestor != null) {
      labels.add(ancestor.label);
    }
  }
  return labels.reversed.join(separator);
}

/// 前序展开某类型的整棵分类树，携带深度，供缩进列表渲染。
List<CategoryNode> flattenTree(List<Category> all, EntryType type) {
  final result = <CategoryNode>[];
  final visited = <String>{};
  void walk(String? parentId, int depth) {
    final children = parentId == null
        ? rootCategories(all, type)
        : childrenOf(all, parentId);
    for (final child in children) {
      if (visited.add(child.id)) {
        result.add(CategoryNode(category: child, depth: depth));
        walk(child.id, depth + 1);
      }
    }
  }

  walk(null, 0);
  return result;
}
