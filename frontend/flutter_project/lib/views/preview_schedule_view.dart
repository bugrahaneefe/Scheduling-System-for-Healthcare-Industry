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

  Map<String, List<Map<String, String>>> _convertScheduleData(Map<String, List<String>> data) {
    print('Converting data: $data'); // Debug print
    final Map<String, List<Map<String, String>>> result = {};
    
    if (data.isEmpty) {
      print('Warning: Input data is empty!');
      return result;
    }
    
    data.forEach((dateStr, doctorNames) {
      print('Processing date: $dateStr with doctors: $doctorNames'); // Debug print
      result[dateStr] = doctorNames.map((name) {
        // Find the participant info for this doctor
        final doctor = widget.participants.firstWhere(
          (p) => p['name'] == name,
          orElse: () => {'name': name, 'assignedUserName': 'Unassigned'},
        );
        print('Found doctor info: $doctor'); // Debug print
        
        return {
          'name': name,
          'assignedUser': (doctor['assignedUserName'] ?? 'Unassigned') as String,
        };
      }).toList();
    });
    print('Conversion result: $result'); // Debug print
    return result;
  }

  Future<void> _removeAssignment(String date, Map<String, String> assignment) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
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
        final dateParts = date.split(' '); // ["1", "February", "2025", "Saturday"]
        final day = int.parse(dateParts[0]);
        final month = _getMonthNumber(dateParts[1]);
        final year = int.parse(dateParts[2]);
        
        // Format the date as DD.MM.YYYY
        final formattedDate = '${day.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year';

        final List<Map<String, dynamic>> convertedAssignments = assignments.map((assignment) {
          final participant = widget.participants.firstWhere(
            (p) => p['name'] == assignment['name'],
            orElse: () => {'name': assignment['name'], 'assignedUserName': 'Unassigned'},
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1B),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Schedule Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _schedule.length,
                itemBuilder: (context, index) {
                  String date = _schedule.keys.elementAt(index);
                  List<Map<String, String>> names = _schedule[date]!;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.white.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
