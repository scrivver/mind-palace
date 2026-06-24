import 'package:flutter/material.dart';

class FilterDropdownPanel extends StatefulWidget {
  final List<({String key, String label, IconData icon})> fileTypes;
  final Set<String> initialSelectedTags;
  final String? initialTypeFilter;
  final List<Map<String, dynamic>> availableTags;
  final void Function(String? type, Set<String> tags) onApply;

  const FilterDropdownPanel({
    super.key,
    required this.fileTypes,
    required this.initialSelectedTags,
    required this.initialTypeFilter,
    required this.availableTags,
    required this.onApply,
  });

  @override
  State<FilterDropdownPanel> createState() => _FilterDropdownPanelState();
}

class _FilterDropdownPanelState extends State<FilterDropdownPanel> {
  late Set<String> _draftSelectedTags;
  late String? _draftTypeFilter;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _draftSelectedTags = Set.from(widget.initialSelectedTags);
    _draftTypeFilter = widget.initialTypeFilter;
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchText = _searchCtrl.text.toLowerCase());
  }

  void _toggleType(String key) {
    setState(() {
      _draftTypeFilter = _draftTypeFilter == key ? null : key;
    });
  }

  void _toggleTag(String name) {
    setState(() {
      if (!_draftSelectedTags.remove(name)) {
        _draftSelectedTags.add(name);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _draftSelectedTags.clear();
      _draftTypeFilter = null;
    });
  }

  void _apply() {
    widget.onApply(_draftTypeFilter, Set.from(_draftSelectedTags));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final typeItems = widget.fileTypes.where((t) => t.key != 'all').map((t) {
      final checked = _draftTypeFilter == t.key;
      final match =
          _searchText.isEmpty || t.label.toLowerCase().contains(_searchText);
      return (
        key: t.key,
        label: t.label,
        icon: t.icon,
        checked: checked,
        match: match,
      );
    }).toList();

    final tagItems = widget.availableTags.map((t) {
      final name = t['name'] as String;
      final count = (t['file_count'] as num?)?.toInt() ?? 0;
      final checked = _draftSelectedTags.contains(name);
      final match =
          _searchText.isEmpty || name.toLowerCase().contains(_searchText);
      return (label: name, count: count, checked: checked, match: match);
    }).toList();

    final allItems = [
      ...typeItems
          .where((i) => i.match)
          .map(
            (i) => _buildItemRow(
              context,
              i.label,
              i.icon,
              i.checked,
              () => _toggleType(i.key),
            ),
          ),
      ...tagItems
          .where((i) => i.match)
          .map(
            (i) => _buildItemRow(
              context,
              '${i.label} (${i.count})',
              Icons.tag,
              i.checked,
              () => _toggleTag(i.label),
            ),
          ),
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
              controller: _searchCtrl,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search tags\u2026',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 0,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
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
          child: ListView(shrinkWrap: true, children: allItems),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: cs.outlineVariant.withAlpha(76)),
            ),
            color: cs.surfaceContainerLow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              TextButton(
                onPressed: _clearAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(
                  'Clear All',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    String label,
    IconData icon,
    bool checked,
    VoidCallback onTap,
  ) {
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
                  borderRadius: BorderRadius.circular(4),
                ),
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
