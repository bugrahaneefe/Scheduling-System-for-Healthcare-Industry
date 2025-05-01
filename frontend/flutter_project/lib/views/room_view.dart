import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:project491/views/home_view.dart';
import 'package:project491/views/preview_schedule_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RoomView extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String roomDescription;
  final List<Map<String, dynamic>> participants;
  final String currentUserId;

  const RoomView({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.roomDescription,
    required this.participants,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView> {
  List<Map<String, dynamic>> _participants = [];
  final TextEditingController _newParticipantController =
      TextEditingController();
  bool _isHost = false;
  Map<String, List<Map<String, String>>>? _appliedSchedule;
  bool _showOnlyMySchedule = false;
  final ScrollController _scheduleScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _participants = widget.participants;
    _isHost = _participants.any(
      (p) => p['isHost'] == true && p['userId'] == widget.currentUserId,
    );
    _loadSchedules().then((_) {
      if (_appliedSchedule != null) {
        final sortedDates = _appliedSchedule!.keys.toList()..sort();
        _scrollToToday(sortedDates);
      }
    });
  }

  @override
  void dispose() {
    _scheduleScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    final roomDoc =
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .get();

    if (roomDoc.exists) {
      setState(() {
        _appliedSchedule = _convertScheduleData(
          roomDoc.data()?['appliedSchedule'],
        );
      });
    }
  }

  Map<String, List<Map<String, String>>>? _convertScheduleData(dynamic data) {
    if (data == null) return null;

    final Map<String, List<Map<String, String>>> result = {};
    (data as Map<String, dynamic>).forEach((key, value) {
      result[key] =
          (value as List)
              .map((item) => Map<String, String>.from(item))
              .toList();
    });
    return result;
  }

  Future<void> _refreshRoom() async {
    try {
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (roomDoc.exists) {
        setState(() {
          _participants = List<Map<String, dynamic>>.from(
            roomDoc.data()?['participants'] ?? [],
          );
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _handleParticipantTap(Map<String, dynamic> participant) async {
    // Check if user is already assigned to another participant
    bool isAlreadyAssigned = _participants.any(
      (p) => p != participant && p['userId'] == widget.currentUserId,
    );

    // If user is not host, use existing assignment logic
    if (!_isHost) {
      if (participant['userId'] != null && participant['userId'].isNotEmpty) {
        // Show warning for assigned participant
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Participant Assigned'),
                content: Text(
                  'This participant is already assigned to ${participant['name']}.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      } else if (isAlreadyAssigned) {
        // Show warning that user is already assigned
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Already Assigned'),
                content: const Text(
                  'You are already assigned to another participant in this room.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      } else {
        // Show confirmation for unassigned participant
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Assign Participant'),
                content: Text(
                  'Do you want to assign yourself to ${participant['name']}? \n You won\'t be able to unassign yourself later.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
        );

        if (confirm == true) {
          try {
            // Get user's name from Firestore
            final userDoc =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.currentUserId)
                    .get();

            final userName = userDoc.data()?['name'] ?? 'Unknown User';

            // Update the participant's userId and assignedUserName
            final int participantIndex = _participants.indexOf(participant);
            if (participantIndex != -1) {
              _participants[participantIndex]['userId'] = widget.currentUserId;
              _participants[participantIndex]['assignedUserName'] = userName;

              // Update in Firestore
              await FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.roomId)
                  .update({'participants': _participants});

              // Add room to user's rooms array if not already there
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.currentUserId)
                  .update({
                    'rooms': FieldValue.arrayUnion([widget.roomId]),
                  });

              // Refresh the room
              await _refreshRoom();
            }
          } catch (e) {
            // Show error dialog
            if (mounted) {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Error'),
                      content: Text('Failed to assign participant: $e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
              );
            }
          }
        }
      }
      return;
    }

    // Host-specific actions
    if (participant['userId'] != null && participant['userId'].isNotEmpty) {
      // Prevent host from unassigning themselves
      if (participant['isHost'] == true &&
          participant['userId'] == widget.currentUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host cannot be unassigned'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show options to remove assigned user
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Remove Assignment'),
              content: Text(
                'Do you want to remove the assigned user from ${participant['name']}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remove'),
                ),
              ],
            ),
      );

      if (confirm == true) {
        await _removeUserFromParticipant(participant);
      }
    } else if (_isHost && !participant['isHost']) {
      // Show options to remove unassigned participant
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Remove Participant'),
              content: Text(
                'Do you want to remove ${participant['name']} from the room?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remove'),
                ),
              ],
            ),
      );

      if (confirm == true) {
        await _removeParticipant(participant);
      }
    }
  }

  Future<void> _removeUserFromParticipant(
    Map<String, dynamic> participant,
  ) async {
    try {
      final int index = _participants.indexOf(participant);

      if (index != -1) {
        // Remove both userId and assignedUserName
        _participants[index]['userId'] = '';
        _participants[index]['assignedUserName'] = null;

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({'participants': _participants});

        await _refreshRoom();
      }
    } catch (e) {
      _showError('Failed to remove user: $e');
    }
  }

  bool _validateConsecutiveDaysShifts(List<int> shifts, int doctorCount) {
    for (int i = 0; i < shifts.length - 1; i++) {
      if (shifts[i] + shifts[i + 1] > doctorCount) {
        return false;
      }
    }
    return true;
  }

  Future<void> _removeParticipant(Map<String, dynamic> participant) async {
    try {
      // Get the room data to check daily shifts
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();
      
      final dailyShifts = List<int>.from(roomDoc.data()?['dailyShifts'] ?? []);
      final updatedDoctorCount = _participants.length - 1; // After removal

      if (!_validateConsecutiveDaysShifts(dailyShifts, updatedDoctorCount)) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cannot Remove Doctor'),
              content: const Text(
                'Removing this doctor would result in consecutive days having more '
                'shifts than available doctors. Please adjust the daily shifts first.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Original removal code
      _participants.remove(participant);

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'participants': _participants});

      await _refreshRoom();
    } catch (e) {
      _showError('Failed to remove participant: $e');
    }
  }

  Future<void> _addNewParticipant() async {
    final name = _newParticipantController.text.trim();
    if (name.isEmpty) return;

    try {
      _participants.add({'userId': '', 'name': name, 'isHost': false});

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'participants': _participants});

      _newParticipantController.clear();
      await _refreshRoom();
    } catch (e) {
      _showError('Failed to add participant: $e');
    }
  }

  Future<void> _deleteRoom() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Room'),
            content: const Text('Are you sure you want to delete this room?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        // Delete the room document
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .delete();

        // Remove room from all participants' rooms arrays
        for (var participant in _participants) {
          if (participant['userId']?.isNotEmpty == true) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(participant['userId'])
                .update({
                  'rooms': FieldValue.arrayRemove([widget.roomId]),
                });
          }
        }

        if (mounted) {
          Navigator.pop(context); // Return to home view
        }
      } catch (e) {
        _showError('Failed to delete room: $e');
      }
    }
  }

  Future<void> _shareRoomInvitation() async {
    if (!_isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the host can share room invitations'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Generate a shareable link with the room ID
    final inviteLink = 'project491://room/${widget.roomId}';

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: inviteLink));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation link copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDateForComparison(String date) {
    // Convert from DD.MM.YYYY to YYYY-MM-DD
    final parts = date.split('.');
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  void _scrollToToday(List<String> sortedDates) {
    if (sortedDates.isEmpty) return;

    final today = DateTime.now();
    final formattedToday =
        '${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';

    final index = sortedDates.indexWhere((date) {
      final dateStr = _formatDateForComparison(date);
      final todayStr = _formatDateForComparison(formattedToday);
      return dateStr.compareTo(todayStr) >= 0;
    });

    if (index != -1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scheduleScrollController.hasClients) {
          _scheduleScrollController.animateTo(
            index * 72.0, // Approximate height of each ListTile
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Widget _buildScheduleList(Map<String, List<Map<String, String>>>? schedule) {
    if (schedule == null) return const SizedBox.shrink();

    // Filter schedule if needed
    Map<String, List<Map<String, String>>> filteredSchedule =
        _showOnlyMySchedule
            ? Map.fromEntries(
              schedule.entries.where((entry) {
                final myParticipantInfo = _participants.firstWhere(
                  (p) => p['userId'] == widget.currentUserId,
                  orElse: () => {},
                );
                return entry.value.any(
                  (assignment) =>
                      assignment['name'] == myParticipantInfo['name'],
                );
              }),
            )
            : schedule;

    final sortedDates =
        filteredSchedule.keys.toList()..sort((a, b) {
          final aDate = DateTime.parse(a.split('.').reversed.join('-'));
          final bDate = DateTime.parse(b.split('.').reversed.join('-'));
          return aDate.compareTo(bDate);
        });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _showOnlyMySchedule = false),
              child: Text(
                'All',
                style: TextStyle(
                  color: !_showOnlyMySchedule ? Colors.blue : Colors.white,
                  fontWeight:
                      !_showOnlyMySchedule
                          ? FontWeight.bold
                          : FontWeight.normal,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showOnlyMySchedule = true),
              child: Text(
                'Me',
                style: TextStyle(
                  color: _showOnlyMySchedule ? Colors.blue : Colors.white,
                  fontWeight:
                      _showOnlyMySchedule ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            controller: _scheduleScrollController,
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final assignments = filteredSchedule[date]!;
              final isToday =
                  date ==
                  '${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}';

              return ListTile(
                title: Text(
                  date,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    backgroundColor:
                        isToday ? Colors.blue.withOpacity(0.3) : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      assignments.map((a) {
                        return _isHost
                            ? Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${a['name']} (${a['assignedUser']})',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () => _removeAssignment(date, a),
                                ),
                              ],
                            )
                            : Text(
                              '${a['name']} (${a['assignedUser']})',
                              style: const TextStyle(color: Colors.white70),
                            );
                      }).toList(),
                ),
                trailing:
                    _isHost
                        ? IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: () => _showAddAssignmentDialog(date),
                        )
                        : null,
              );
            },
          ),
        ),
      ],
    );
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
      try {
        final updatedSchedule = Map<String, List<Map<String, String>>>.from(
          _appliedSchedule!,
        );
        updatedSchedule[date]!.removeWhere(
          (a) =>
              a['name'] == assignment['name'] &&
              a['assignedUser'] == assignment['assignedUser'],
        );

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({'appliedSchedule': updatedSchedule});

        await _loadSchedules();
      } catch (e) {
        _showError('Failed to remove assignment: $e');
      }
    }
  }

  Future<void> _showAddAssignmentDialog(String date) async {
    // Check for users already assigned on this date
    final List<String> assignedUsers =
        _appliedSchedule![date]!
            .map((assignment) => assignment['name'] as String)
            .toList();

    final availableParticipants =
        _participants.where((p) => !assignedUsers.contains(p['name'])).toList();

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
          _appliedSchedule!,
        );
        updatedSchedule[date]!.add({
          'name': selectedParticipant['name'],
          'assignedUser':
              selectedParticipant['assignedUserName'] ?? 'Unassigned',
        });

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({'appliedSchedule': updatedSchedule});

        await _loadSchedules();
      } catch (e) {
        _showError('Failed to add assignment: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFF0D0D1B),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween, // Changed to spaceBetween
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeView()),
                            (route) => false,
                          );
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.roomName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (_isHost)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.share,
                                color: Colors.white,
                              ),
                              onPressed: _shareRoomInvitation,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: _deleteRoom,
                            ),
                          ],
                        ),
                      if (!_isHost) const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_appliedSchedule != null)
                    _buildScheduleList(_appliedSchedule),
                  const SizedBox(height: 16),
                  if (_isHost)
                    ElevatedButton(
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        );

                        try {
                          // Filter participants to get only doctors (non-host users)
                          final doctors = _participants
                              .map((p) => p['name'] as String)
                              .toList();

                          if (doctors.isEmpty) {
                            Navigator.pop(context);
                            _showError('No doctors found in the room. Please add participants first.');
                            return;
                          }

                          final roomDoc = await FirebaseFirestore.instance
                              .collection('rooms')
                              .doc(widget.roomId)
                              .get();

                          final data = roomDoc.data();
                          final firstDay = data?['firstDay'] as String;
                          final lastDay = data?['lastDay'] as String;
                          final dailyShifts = List<int>.from(data?['dailyShifts'] ?? []);

                          // Prepare the input data with doctors from participants
                          final inputData = {
                            'firstDay': firstDay,
                            'lastDay': lastDay,
                            'doctors': doctors,
                            'numShifts': List.filled(doctors.length, 10), // Default 10 shifts per doctor
                            'dailyShifts': dailyShifts,
                            'availabilityMatrix': List.generate(
                              doctors.length,
                              (index) => List.filled(dailyShifts.length, 0), // Default all available
                            ),
                          };

                          // Make API request
                          final response = await http.post(
                            Uri.parse('http://127.0.0.1:8000/api/generate-schedule/'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode(inputData),
                          );

                          if (response.statusCode == 200) {
                            final resultData = jsonDecode(response.body);
                            print('API Response: $resultData'); // Debug print
                            
                            // Extract the schedule from the response
                            final scheduleData = resultData['schedule'] as Map<String, dynamic>;
                            
                            // Convert API response to schedule format
                            final Map<String, List<String>> schedule = {};
                            scheduleData.forEach((date, doctors) {
                              if (doctors is List) {
                                print('Processing date: $date, doctors: $doctors'); // Debug print
                                schedule[date] = List<String>.from(doctors);
                              }
                            });
                            
                            print('Final schedule: $schedule'); // Debug print

                            Navigator.pop(context); // Remove loading dialog
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PreviewScheduleView(
                                  participants: _participants,
                                  roomId: widget.roomId,
                                  scheduleData: schedule,
                                ),
                              ),
                            );

                            // If returned with refresh flag, reload the data
                            if (result == true) {
                              await _loadSchedules();
                              await _refreshRoom();
                            }
                          } else {
                            Navigator.pop(context); // Remove loading dialog
                            _showError('Failed to fetch schedule: ${response.body}');
                          }
                        } catch (e) {
                          Navigator.pop(context); // Remove loading dialog
                          _showError('Error occurred: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text(
                        'Preview New Schedule',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.roomDescription,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Participants',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isHost)
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newParticipantController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Add new participant',
                                    hintStyle: TextStyle(color: Colors.white60),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _addNewParticipant(),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                                onPressed: _addNewParticipant,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height - 300,
                    child: ListView.builder(
                      itemCount: _participants.length,
                      itemBuilder: (context, index) {
                        final participant = _participants[index];
                        return InkWell(
                          onTap: () => _handleParticipantTap(participant),
                          child: _buildParticipantRow(
                            participant['name'],
                            _getParticipantStatusColor(participant),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantRow(String name, Color statusColor) {
    // Find participant data
    final participant = _participants.firstWhere(
      (p) => p['name'] == name,
      orElse: () => <String, dynamic>{},
    );

    bool isHost = participant['isHost'] == true;
    String? assignedUserName = participant['assignedUserName'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: isHost ? Border.all(color: Colors.blue, width: 3.0) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isHost || assignedUserName != null)
                  Text(
                    '${isHost ? "Host" : ""}${isHost && assignedUserName != null ? " • " : ""}${assignedUserName != null ? "Assigned to: $assignedUserName" : ""}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Color _getParticipantStatusColor(Map<String, dynamic> participant) {
    if (participant['userId'] == null || participant['userId'].isEmpty) {
      return Colors.grey; // No assigned userId
    }
    if (participant['userId'] == widget.currentUserId) {
      return Colors.green; // Current user
    }
    return Colors.red; // Other assigned user
  }
}
