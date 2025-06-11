import 'package:flutter/material.dart';
import 'package:project491/utils/app_localizations.dart';

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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (widget.firstDay.isBefore(today)) {
      _firstDay = today;
      _lastDay =
          widget.lastDay.isBefore(today) ||
                  widget.lastDay.isAtSameMomentAs(today)
              ? today.add(const Duration(days: 1))
              : widget.lastDay;
    } else {
      _firstDay = widget.firstDay;
      _lastDay = widget.lastDay;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        AppLocalizations.of(context).get('editRoomDates'),
        style: TextStyle(color: Colors.black),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              AppLocalizations.of(context).get('firstDay'),
              style: TextStyle(color: Colors.black),
            ),
            subtitle: Text(
              _formatDate(_firstDay),
              style: const TextStyle(color: Colors.black54),
            ),
            onTap: () async {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _firstDay.isBefore(today) ? today : _firstDay,
                firstDate: today,
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF1D61E7),
                        surface: Colors.white,
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
            title: Text(
              AppLocalizations.of(context).get('lastDay'),
              style: TextStyle(color: Colors.black),
            ),
            subtitle: Text(
              _formatDate(_lastDay),
              style: const TextStyle(color: Colors.black54),
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
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF1D61E7),
                        surface: Colors.white,
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
          child: Text(
            AppLocalizations.of(context).get('cancel'),
            style: TextStyle(color: Colors.black),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF1D61E7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: () {
            Navigator.pop(context, {
              'firstDay': _firstDay,
              'lastDay': _lastDay,
            });
          },
          child: Text(
            AppLocalizations.of(context).get('save'),
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
