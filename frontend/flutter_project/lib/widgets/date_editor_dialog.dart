import 'package:flutter/material.dart';

class DateEditorDialog extends StatefulWidget {
  final DateTime firstDay;
  final DateTime lastDay;

  const DateEditorDialog({
    Key? key,
    required this.firstDay,
    required this.lastDay,
  }) : super(key: key);

  @override
  State<DateEditorDialog> createState() => _DateEditorDialogState();
}

class _DateEditorDialogState extends State<DateEditorDialog> {
  late DateTime _firstDay;
  late DateTime _lastDay;

  @override
  void initState() {
    super.initState();
    _firstDay = widget.firstDay;
    _lastDay = widget.lastDay;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: const Text(
        'Edit Room Dates',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text(
              'First Day',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              _formatDate(_firstDay),
              style: const TextStyle(color: Colors.white70),
            ),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _firstDay,
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.blue,
                        surface: Color(0xFF1E1E2E),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _firstDay = picked);
                if (_lastDay.isBefore(_firstDay)) {
                  setState(() => _lastDay = _firstDay);
                }
              }
            },
          ),
          ListTile(
            title: const Text(
              'Last Day',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              _formatDate(_lastDay),
              style: const TextStyle(color: Colors.white70),
            ),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _lastDay,
                firstDate: _firstDay,
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.blue,
                        surface: Color(0xFF1E1E2E),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _lastDay = picked);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, {
              'firstDay': _firstDay,
              'lastDay': _lastDay,
            });
          },
          child: const Text('Save', style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
