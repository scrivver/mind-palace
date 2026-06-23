import 'package:flutter/material.dart';

class FilterDropdownPanel extends StatefulWidget {
  final List<({String key, String label, IconData icon})> fileTypes;
  final TextEditingController searchCtrl;
  final Set<String> draftSelectedTags;
  final String? draftTypeFilter;
  final List<Map<String, dynamic>> availableTags;
  final void Function(String key) onToggleType;
  final void Function(String name) onToggleTag;
  final VoidCallback onClearAll;
  final VoidCallback onApply;

  const FilterDropdownPanel({
    super.key,
    required this.fileTypes,
    required this.searchCtrl,
    required this.draftSelectedTags,
    required this.draftTypeFilter,
    required this.availableTags,
    required this.onToggleType,
    required this.onToggleTag,
    required this.onClearAll,
    required this.onApply,
  });

  @override
  State<FilterDropdownPanel> createState() => _FilterDropdownPanelState();
}

class _FilterDropdownPanelState extends State<FilterDropdownPanel> {
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    widget.searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchText = widget.searchCtrl.text.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final typeItems =
        widget.fileTypes.where((t) => t.key != 'all').map((t) {
      final checked = widget.draftTypeFilter == t.key;
      final match =
          _searchText.isEmpty || t.label.toLowerCase().contains(_searchText);
      return (key: t.key, label: t.label, icon: t.icon, checked: checked, match: match);
    }).toList();

    final tagItems = widget.availableTags.map((t) {
      final name = t['name'] as String;
      final count = (t['file_count'] as num?)?.toInt() ?? 0;
      final checked = widget.draftSelectedTags.contains(name);
      final match =
          _searchText.isEmpty || name.toLowerCase().contains(_searchText);
      return (label: name, count: count, checked: checked, match: match);
    }).toList();

    final allItems = [
      ...typeItems
          .where((i) => i.match)
          .map((i) => _buildItemRow(
              context, i.label, i.icon, i.checked, () => widget.onToggleType(i.key))),
      ...tagItems
          .where((i) => i.match)
          .map((i) => _buildItemRow(context, i.label, Icons.tag, i.checked,
              () => widget.onToggleTag(i.label))),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: widget.searchCtrl,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search tags\u2026',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 32, minHeight: 0),
                prefixIcon: Icon(Icons.search,
                    size: 16, color: cs.onSurfaceVariant),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView(
            shrinkWrap: true,
            children: allItems,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: cs.outlineVariant.withAlpha(76))),
            color: cs.surfaceContainerLow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              TextButton(
                onPressed: widget.onClearAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600),
                ),
                child: Text('Clear All',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: widget.onApply,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(BuildContext context, String label, IconData icon,
      bool checked, VoidCallback onTap) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: checked,
                onChanged: (_) => onTap(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: cs.outlineVariant),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
