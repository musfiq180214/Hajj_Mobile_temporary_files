import 'package:flutter/material.dart';
import 'package:labbayk/core/theme/colors.dart';

typedef OnItemSelected<T> = void Function(T? selected);

class DynamicDropdown<T> extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? selectedItem;
  final String idKey;
  final String titleKey;
  final bool enabled;
  final OnItemSelected<Map<String, dynamic>>? onChanged;

  const DynamicDropdown({
    super.key,
    required this.label,
    required this.items,
    this.selectedItem,
    this.idKey = 'id',
    this.titleKey = 'title',
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: selectedItem != null
          ? int.tryParse(selectedItem![idKey].toString())
          : null,
      hint: Text(
        label,
        style: TextStyle(color: enabled ? textColorPrimary : Colors.grey),
      ),
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      items: enabled
          ? items.map((item) {
              return DropdownMenuItem<int>(
                value: int.tryParse(item[idKey].toString()),
                child: Text(item[titleKey] ?? ''),
              );
            }).toList()
          : [],
      onChanged: enabled
          ? (val) {
              if (val == null) return;
              final selected = items
                  .firstWhere((i) => int.tryParse(i[idKey].toString()) == val);
              if (onChanged != null) onChanged!(selected);
            }
          : null,
    );
  }
}
