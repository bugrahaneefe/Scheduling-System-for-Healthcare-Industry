import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    print('Schedule Data received: ${widget.scheduleData}'); // Debug print
    _schedule = _convertScheduleData(widget.scheduleData);
    print('Converted Schedule: $_schedule'); // Debug print
  }

  Map<String, List<Map<String, String>>> _convertScheduleData(
    Map<String, List<String>> data,
  ) {
    print('Converting data: $data'); // Debug print
    final Map<String, List<Map<String, String>>> result = {};

    if (data.isEmpty) {
      print('Warning: Input data is empty!');
      return result;
    }

    data.forEach((dateStr, doctorNames) {
      print(
        'Processing date: $dateStr with doctors: $doctorNames',
      ); // Debug print
      result[dateStr] =
          doctorNames.map((name) {
            // Find the participant info for this doctor
            final doctor = widget.participants.firstWhere(
              (p) => p['name'] == name,
              orElse: () => {'name': name, 'assignedUserName': 'Unassigned'},
            );
            print('Found doctor info: $doctor'); // Debug print

            return {
              'name': name,
              'assignedUser':
                  (doctor['assignedUserName'] ?? 'Unassigned') as String,
            };
          }).toList();
    });
    print('Conversion result: $result'); // Debug print
    return result;
  }

  Future<void> _removeAssignment(
    String date,
    Map<String, String> assignment,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Assignment'),
            content: Text('Remove ${assignment['name']} from $date?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
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
        const SnackBar(
          content: Text('All participants are already assigned for this day'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedParticipant = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Assignment for $date'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableParticipants.length,
                itemBuilder: (context, index) {
                  final participant = availableParticipants[index];
                  return ListTile(
                    title: Text(participant['name']),
                    subtitle: Text(
                      participant['assignedUserName'] ?? 'Unassigned',
                    ),
                    onTap: () => Navigator.pop(context, participant),
                  );
                },
              ),
            ),
          ),
    );

    if (selectedParticipant != null) {
      try {
        final updatedSchedule = Map<String, List<Map<String, String>>>.from(
          _schedule,
        );
        updatedSchedule[date]!.add({
          'name': selectedParticipant['name'],
          'assignedUser':
              selectedParticipant['assignedUserName'] ?? 'Unassigned',
        });

        setState(() {
          _schedule = updatedSchedule;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add assignment: $e'),
            backgroundColor: Colors.red,
          ),
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
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Convert schedule to format expected by Firestore
      final Map<String, List<Map<String, dynamic>>> convertedSchedule = {};
      schedule.forEach((date, assignments) {
        // Extract the date parts from the formatted date (e.g., "1 February 2025 Saturday")
        final dateParts = date.split(
          ' ',
        ); // ["1", "February", "2025", "Saturday"]
        final day = int.parse(dateParts[0]);
        final month = _getMonthNumber(dateParts[1]);
        final year = int.parse(dateParts[2]);

        // Format the date as DD.MM.YYYY
        final formattedDate =
            '${day.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year';

        final List<Map<String, dynamic>> convertedAssignments =
            assignments.map((assignment) {
              final participant = widget.participants.firstWhere(
                (p) => p['name'] == assignment['name'],
                orElse:
                    () => {
                      'name': assignment['name'],
                      'assignedUserName': 'Unassigned',
                    },
              );

              return {
                'name': assignment['name'],
                'assignedUser': participant['assignedUserName'] ?? 'Unassigned',
              };
            }).toList();

        convertedSchedule[formattedDate] = convertedAssignments;
      });

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'appliedSchedule': convertedSchedule});

      if (context.mounted) {
        Navigator.pop(context); // Remove loading dialog
        Navigator.pop(context, true); // Return to room view with refresh flag
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Remove loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to convert month name to number
  int _getMonthNumber(String monthName) {
    final months = {
      'January': 1,
      'February': 2,
      'March': 3,
      'April': 4,
      'May': 5,
      'June': 6,
      'July': 7,
      'August': 8,
      'September': 9,
      'October': 10,
      'November': 11,
      'December': 12,
    };
    return months[monthName] ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate duty counts for each participant
    final Map<String, int> dutyCounts = {};
    widget.scheduleData.forEach((date, doctors) {
      for (final doctor in doctors) {
        dutyCounts[doctor] = (dutyCounts[doctor] ?? 0) + 1;
      }
    });

    // Optionally, get participant display names from participants list
    String getDisplayName(String name) {
      final participant = widget.participants.firstWhere(
        (p) => p['name'] == name,
        orElse: () => {'name': name, 'assignedUserName': null},
      );
      return participant['assignedUserName'] != null
          ? '${participant['name']} (${participant['assignedUserName']})'
          : name;
    }

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
      backgroundColor: const Color(0xFF0D0D1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Preview Schedule',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 40.0, bottom: 16.0),
              child: Card(
                color: Colors.blue.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Duties per Participant',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Use a local controller for each Scrollbar/ScrollView pair
                      SizedBox(
                        height: 56,
                        child: Builder(
                          builder: (context) {
                            final horizontalScrollController =
                                ScrollController();
                            return Stack(
                              children: [
                                // Duty chips row
                                SingleChildScrollView(
                                  controller: horizontalScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children:
                                        dutyCounts.entries.map((entry) {
                                          return Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  getDisplayName(entry.key),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                        horizontal: 12,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    entry.value.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                                // Scrollbar at the bottom with a little padding
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom:
                                      4, // add a little padding from the bottom
                                  child: Scrollbar(
                                    controller: horizontalScrollController,
                                    thumbVisibility: true,
                                    thickness: 6,
                                    radius: const Radius.circular(8),
                                    notificationPredicate: (_) => false,
                                    child: SizedBox(height: 8),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _schedule.length,
                itemBuilder: (context, index) {
                  String date = sortedDates[index];
                  List<Map<String, String>> names = _schedule[date]!;

                  final isToday = date == todayStr;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color:
                        isToday
                            ? Colors.blue.withOpacity(0.25)
                            : Colors.white.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date + (isToday ? " (Today)" : ""),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              backgroundColor:
                                  isToday
                                      ? Colors.blue.withOpacity(0.15)
                                      : null,
                            ),
                          ),
                          const Divider(color: Colors.white30),
                          ...names.map(
                            (info) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '• ${info['name']} (${info['assignedUser']})',
                                      style: const TextStyle(
                                        color: Colors.white70,
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
                            icon: const Icon(Icons.add, color: Colors.green),
                            onPressed: () => _showAddAssignmentDialog(date),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => _applySchedule(context, _schedule),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text(
                  'Apply Schedule',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
