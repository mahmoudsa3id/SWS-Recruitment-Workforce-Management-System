import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sales-person autocomplete backed by existing traveler records.
/// A value not present in the suggestions is still accepted as a new name;
/// it is saved with the traveler and will appear in suggestions afterwards.
class SalesPersonField extends StatefulWidget {
  const SalesPersonField({
    super.key,
    required this.controller,
    this.label = 'مسؤول السيلز',
  });

  final TextEditingController controller;
  final String label;

  @override
  State<SalesPersonField> createState() => _SalesPersonFieldState();
}

class _SalesPersonFieldState extends State<SalesPersonField> {
  late Future<List<String>> _namesFuture;

  @override
  void initState() {
    super.initState();
    _namesFuture = _loadNames();
  }

  Future<List<String>> _loadNames() async {
    final names = <String, String>{};
    var offset = 0;
    const pageSize = 500;
    try {
      while (true) {
        final rows = await Supabase.instance.client
            .from('travelers')
            .select('sales_person')
            .not('sales_person', 'is', null)
            .order('sales_person')
            .range(offset, offset + pageSize - 1);
        for (final row in rows) {
          final name = (row['sales_person'] as String? ?? '').trim();
          if (name.isNotEmpty) {
            names.putIfAbsent(name.toLowerCase(), () => name);
          }
        }
        if (rows.length < pageSize) break;
        offset += pageSize;
      }
    } catch (_) {
      // The field remains usable for new names if suggestions cannot be loaded.
    }
    final result = names.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _namesFuture,
      builder: (context, snapshot) {
        final names = snapshot.data ?? const <String>[];
        return Autocomplete<String>(
          key: ValueKey(widget.label),
          initialValue: TextEditingValue(text: widget.controller.text),
          displayStringForOption: (option) => option,
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            final matches = query.isEmpty
                ? names
                : names.where((name) => name.toLowerCase().contains(query));
            return matches.take(8);
          },
          onSelected: (value) {
            widget.controller.value = TextEditingValue(
              text: value,
              selection: TextSelection.collapsed(offset: value.length),
            );
          },
          fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              onChanged: (value) => widget.controller.value = TextEditingValue(
                text: value,
                selection: TextSelection.collapsed(offset: value.length),
              ),
              onFieldSubmitted: (_) {
                widget.controller.text = textController.text.trim();
                onSubmitted();
              },
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: 'اختر اسمًا موجودًا أو اكتب اسمًا جديدًا',
                suffixIcon: snapshot.connectionState == ConnectionState.waiting
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.support_agent_outlined),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final items = options.toList(growable: false);
            if (items.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.topRight,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    maxWidth: 400,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline_rounded),
                      title: Text(items[index]),
                      onTap: () => onSelected(items[index]),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
