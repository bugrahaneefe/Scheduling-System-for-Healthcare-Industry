import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project491/utils/app_localizations.dart';
import 'package:intl/intl.dart';

class PreviewScheduleView extends StatefulWidget {
  final List<Map<String, dynamic>> participants;
  final String roomId;
  final Map<String, List<String>> scheduleData; // Update type definition

  const PreviewScheduleView({
    Key? key,
    required this.participants,
    required this.roomId,
    required this.scheduleData,
  }) : super(key: key);

  @override
  _PreviewScheduleViewState createState() => _PreviewScheduleViewState();
}

class _PreviewScheduleViewState extends State<PreviewScheduleView> {
  late Map<String, List<Map<String, String>>> _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = _convertScheduleData(widget.scheduleData);
  }

  Map<String, List<Map<String, String>>> _convertScheduleData(
    Map<String, List<String>> data,
  ) {
    final Map<String, List<Map<String, String>>> result = {};

    if (data.isEmpty) {
      return result;
    }

    data.forEach((dateStr, doctorNames) {
      result[dateStr] =
          doctorNames.map((name) {
            // Find the participant info for this doctor
            final doctor = widget.participants.firstWhere(
              (p) => p['name'] == name,
              orElse: () => {'name': name, 'assignedUserName': 'Unassigned'},
            );

            return {
              'name': name,
              'assignedUser':
                  (doctor['assignedUserName'] ?? 'Unassigned') as String,
            };
          }).toList();
    });
    return result;
  }

  Future<void> _removeAssignment(
    String date,
    Map<String, String> assignment,
  ) async {
    final message = AppLocalizations.of(context).translate(
      'removeAssignmentFor',
      params: {'username': assignment['name'] ?? "", 'date': date},
    );
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(
              AppLocalizations.of(context).get('removeAssignment'),
              style: TextStyle(color: Colors.black),
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black, // Changed to black
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context).get('cancel')),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  AppLocalizations.of(context).get('remove'),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() {
        _schedule[date]!.removeWhere(
          (a) =>
              a['name'] == assignment['name'] &&
              a['assignedUser'] == assignment['assignedUser'],
        );
      });
    }
  }

  Future<void> _showAddAssignmentDialog(String date) async {
    // Check for users already assigned on this date
    final List<String> assignedUsers =
        _schedule[date]!
            .map((assignment) => assignment['name'] as String)
            .toList();

    final availableParticipants =
        widget.participants
            .where((p) => !assignedUsers.contains(p['name']))
            .toList();

    if (availableParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).get('allParticipantsAssigned'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final message = AppLocalizations.of(context).get('addAssignmentFor');
    final parts = date.split(' ');
    final parsedDate = DateTime(
      int.parse(parts[2]),
      _getMonthNumber(parts[1]),
      int.parse(parts[0]),
    );
    final locale = Localizations.localeOf(context).languageCode;
    final localizedDate = DateFormat.yMMMMEEEEd(locale).format(parsedDate);
    final selectedParticipant = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(
              '$message\n$localizedDate',
              style: const TextStyle(color: Colors.black),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableParticipants.length,
                itemBuilder: (context, index) {
                  final participant = availableParticipants[index];
                  final assignedUserName = participant['assignedUserName'];

                  return ListTile(
                    title: Text(
                      participant['name'],
                      style: const TextStyle(color: Colors.black87),
                    ),
                    subtitle:
                        (assignedUserName != null &&
                                assignedUserName.toString().trim().isNotEmpty)
                            ? Text(
                              assignedUserName,
                              style: const TextStyle(color: Colors.black54),
                            )
                            : null,
                    onTap: () => Navigator.pop(context, participant),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black, // Changed to black
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).get('cancel')),
              ),
            ],
          ),
    );

    if (selectedParticipant != null) {
      try {
        final updatedSchedule = Map<String, List<Map<String, String>>>.from(
          _schedule,
        );
        updatedSchedule[date]!.add({
          'name': selectedParticipant['name'],
          'assignedUser': selectedParticipant['assignedUserName'] ?? '',
        });

        setState(() {
          _schedule = updatedSchedule;
        });
      } catch (e) {
        final message = AppLocalizations.of(
          context,
        ).get('failedToAddAssignment');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$message$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _applySchedule(
    BuildContext context,
    Map<String, List<Map<String, String>>> schedule,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
      );

      // Convert schedule to format expected by Firestore
      final Map<String, List<Map<String, dynamic>>> convertedSchedule = {};
      schedule.forEach((date, assignments) {
        final dateParts = date.split(' ');
        final day = int.parse(dateParts[0]);
        final month = _getMonthNumber(dateParts[1]);
        final year = int.parse(dateParts[2]);

        final formattedDate =
            '${day.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year';

        final List<Map<String, dynamic>> convertedAssignments =
            assignments.map((assignment) {
              final participant = widget.participants.firstWhere(
                (p) => p['name'] == assignment['name'],
                orElse:
                    () => {'name': assignment['name'], 'assignedUserName': ''},
              );

              return {
                'name': assignment['name'],
                'assignedUser': participant['assignedUserName'] ?? '',
              };
            }).toList();

        convertedSchedule[formattedDate] = convertedAssignments;
      });

      // Update Firestore with new schedule
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'appliedSchedule': convertedSchedule});

      // 🔔 Notify all assigned users in the room
      final now = DateTime.now();
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();
      final roomName =
          roomDoc.data()?['name'] ??
          AppLocalizations.of(context).get('unNamedRoom');

      final message = AppLocalizations.of(
        context,
      ).translate('scheduleAppliedMessage', params: {'roomName': roomName});

      for (final participant in widget.participants) {
        final userId = participant['userId'];
        if (userId != null && userId.toString().isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .add({
                'message': message,
                'roomId': widget.roomId,
                'roomName': roomName,
                'timestamp': now,
                'type': 'schedule_applied',
              });
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // Remove loading dialog
        Navigator.pop(context, true); // Return to RoomView with refresh flag
      }
    } catch (e) {
      if (context.mounted) {
        final message = AppLocalizations.of(
          context,
        ).get('failedToApplySchedule');
        Navigator.pop(context); // Remove loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$message$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper method to convert month name to number
  int _getMonthNumber(String monthName) {
    final lower = monthName.toLowerCase();

    // Hem İngilizce hem Türkçe ayları destekle
    switch (lower) {
      case 'january':
      case 'ocak':
        return 1;
      case 'february':
      case 'şubat':
        return 2;
      case 'march':
      case 'mart':
        return 3;
      case 'april':
      case 'nisan':
        return 4;
      case 'may':
      case 'mayıs':
        return 5;
      case 'june':
      case 'haziran':
        return 6;
      case 'july':
      case 'temmuz':
        return 7;
      case 'august':
      case 'ağustos':
        return 8;
      case 'september':
      case 'eylül':
        return 9;
      case 'october':
      case 'ekim':
        return 10;
      case 'november':
      case 'kasım':
        return 11;
      case 'december':
      case 'aralık':
        return 12;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort schedule keys (dates)
    List<String> sortedDates = _schedule.keys.toList();
    try {
      sortedDates.sort((a, b) {
        try {
          final aParts = a.split(' ');
          final bParts = b.split(' ');

          // Parse dates from both date formats
          final DateTime aDate =
              aParts.length == 4
                  ? DateTime(
                    int.parse(aParts[2]),
                    _getMonthNumber(aParts[1]),
                    int.parse(aParts[0]),
                  )
                  : DateTime.parse(a.split('.').reversed.join('-'));

          final DateTime bDate =
              bParts.length == 4
                  ? DateTime(
                    int.parse(bParts[2]),
                    _getMonthNumber(bParts[1]),
                    int.parse(bParts[0]),
                  )
                  : DateTime.parse(b.split('.').reversed.join('-'));

          return aDate.compareTo(bDate);
        } catch (e) {
          print('Error sorting dates $a and $b: $e');
          return 0;
        }
      });
    } catch (e) {
      print('Error during date sorting: $e');
    }

    // Find index of today or next closest date
    final now = DateTime.now();
    final todayStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    int todayIndex = sortedDates.indexWhere((d) {
      try {
        DateTime dDate;
        if (d.contains(' ')) {
          // "21 May 2025 Wednesday" formatı
          final parts = d.split(' ');
          final day = int.parse(parts[0]);
          final month = _getMonthNumber(parts[1]);
          final year = int.parse(parts[2]);
          dDate = DateTime(year, month, day);
        } else {
          // "DD.MM.YYYY" formatı
          final parts = d.split('.');
          dDate = DateTime(
            int.parse(parts[2]), // year
            int.parse(parts[1]), // month
            int.parse(parts[0]), // day
          );
        }

        final todayParts = todayStr.split('.');
        final todayDate = DateTime(
          int.parse(todayParts[2]),
          int.parse(todayParts[1]),
          int.parse(todayParts[0]),
        );

        return !dDate.isBefore(todayDate);
      } catch (e) {
        print('Error parsing date: $e for date: $d');
        return false;
      }
    });
    if (todayIndex == -1) todayIndex = 0;

    final scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients && sortedDates.isNotEmpty) {
        scrollController.jumpTo(todayIndex * 120.0); // Approximate card height
      }
    });

    // Create a controller for the horizontal Scrollbar (must be unique per widget)
    // DO NOT share this controller between multiple ScrollViews!
    // Instead, create it inside the widget that uses it.
    return Scaffold(
      backgroundColor: const Color(0x1E1E1E),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(
          16.0,
          8.0,
          16.0,
          24.0,
        ), // Left, Top, Right, Bottom
        child: ElevatedButton(
          onPressed: () => _applySchedule(context, _schedule),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D61E7),
            minimumSize: const Size.fromHeight(50),
          ),
          child: Text(
            AppLocalizations.of(context).get('applySchedule'),
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    margin: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).get('previewSchedule'),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _schedule.length,
                  itemBuilder: (context, index) {
                    String date = sortedDates[index];
                    List<Map<String, String>> names = _schedule[date]!;

                    // Parse the date
                    DateTime parsedDate;
                    if (date.contains(' ')) {
                      final parts = date.split(' ');
                      final day = int.parse(parts[0]);
                      final month = _getMonthNumber(parts[1]);
                      final year = int.parse(parts[2]);
                      parsedDate = DateTime(year, month, day);
                    } else {
                      final parts = date.split('.');
                      parsedDate = DateTime(
                        int.parse(parts[2]),
                        int.parse(parts[1]),
                        int.parse(parts[0]),
                      );
                    }

                    // Check if it's today
                    final now = DateTime.now();
                    final isToday =
                        parsedDate.year == now.year &&
                        parsedDate.month == now.month &&
                        parsedDate.day == now.day;

                    // Localize the date string
                    final locale = Localizations.localeOf(context).languageCode;
                    final localizedDateStr = DateFormat.yMMMMEEEEd(
                      locale,
                    ).format(parsedDate);
                    final todayLabel = AppLocalizations.of(
                      context,
                    ).get('today');

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizedDateStr +
                                  (isToday ? " ($todayLabel)" : ""),
                              style: const TextStyle(
                                // Black text for all dates
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(color: Colors.black38),
                            ...names.map(
                              (info) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '• ${info['name']}',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed:
                                          () => _removeAssignment(date, info),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                color: const Color(0xFF1D61E7),
                              ),
                              onPressed: () => _showAddAssignmentDialog(date),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
