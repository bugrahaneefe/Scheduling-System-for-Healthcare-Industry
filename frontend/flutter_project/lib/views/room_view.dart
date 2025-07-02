import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:project491/services/ad_test_service.dart';
import 'package:project491/views/preview_schedule_view.dart';
import 'package:project491/views/set_duties_view.dart';
import 'package:project491/utils/app_localizations.dart';
import 'package:project491/views/view_preferences_view.dart';
import 'package:project491/views/home_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/date_editor_dialog.dart';
import 'package:excel/excel.dart' as excel_import;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

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
  Map<int, Map<String, dynamic>> _doctorPreferences = {};

  // Add this field to track if schedule is applied
  bool _isScheduleApplied = false;
  final PageController _pageController = PageController();
  late final Future<DocumentSnapshot> _roomDocFuture;

  @override
  void initState() {
    super.initState();
    _roomDocFuture =
        FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
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
    _loadAllDoctorPreferences();
    _checkScheduleStatus();
  }

  void _checkScheduleStatus() {
    setState(() {
      _isScheduleApplied = _appliedSchedule != null;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scheduleScrollController.dispose();
    super.dispose();
  }

  void _handlePageChange(int delta) {
    final nextPage = _pageController.page!.round() + delta;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
        _isScheduleApplied = _appliedSchedule != null;
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

  Future<void> _loadAllDoctorPreferences() async {
    try {
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        return;
      }

      final roomData = roomDoc.data()!;
      final firstDay = roomData['firstDay'] as String;
      final lastDay = roomData['lastDay'] as String;

      final preferencesSnapshot =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .collection('preferences')
              .get();

      setState(() {
        _doctorPreferences.clear();
        for (var doc in preferencesSnapshot.docs) {
          final doctorName = doc.id;
          final data = doc.data();

          if (_participants.any((p) => p['name'] == doctorName)) {
            final List<int> availability =
                (data['availability'] as List<dynamic>?)
                    ?.map((e) => e as int)
                    .toList() ??
                [];

            // Always include firstDay and lastDay from room document
            _doctorPreferences[_participants.indexWhere(
              (p) => p['name'] == doctorName,
            )] = {
              'shiftsCount': data['shiftsCount'] as int,
              'availability': availability,
              'firstDay': firstDay,
              'lastDay': lastDay,
            };
          }
        }
      });
    } catch (e) {}
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
        final message = AppLocalizations.of(
          context,
        ).get('participantAssignedTo');
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text(
                  AppLocalizations.of(context).get('participantAssigned'),
                  style: TextStyle(color: Colors.black),
                ),
                content: Text(
                  '$message${participant['name']}',
                  style: const TextStyle(color: Colors.black87),
                ),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF1D61E7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context).get('ok'),
                      style: TextStyle(color: Colors.white),
                    ),
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
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text(
                  AppLocalizations.of(context).get('alreadyAssigned'),
                  style: TextStyle(color: Colors.black),
                ),
                content: Text(
                  AppLocalizations.of(context).get('assignedAlready'),
                  style: TextStyle(color: Colors.black87),
                ),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF1D61E7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context).get('ok'),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        );
      } else {
        final message1 = AppLocalizations.of(context).get('wantToAssign');
        final message2 = AppLocalizations.of(
          context,
        ).get('willNotAbleToUnassign');
        // Show confirmation for unassigned participant
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text(
                  AppLocalizations.of(context).get('assignParticipant'),
                  style: TextStyle(color: Colors.black),
                ),
                content: Text(
                  '$message1${participant['name']}? \n\n$message2',
                  style: const TextStyle(color: Colors.black87),
                ),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      AppLocalizations.of(context).get('cancel'),
                      style: TextStyle(color: Color(0xFF1D61E7)),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF1D61E7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      AppLocalizations.of(context).get('yes'),
                      style: TextStyle(color: Colors.white),
                    ),
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

            final userName =
                userDoc.data()?['name'] ??
                AppLocalizations.of(context).get('unknownUser');

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

              // Notify host
              final hostParticipant = _participants.firstWhere(
                (p) => p['isHost'] == true,
                orElse: () => {},
              );

              final hostUserId = hostParticipant['userId'];
              final participantName = participant['name'];
              final message = AppLocalizations.of(context).translate(
                'selfAssignmentMessage',
                params: {
                  'userName': userName,
                  'participantName': participantName,
                  'roomName': widget.roomName,
                },
              );

              if (hostUserId != null && hostUserId.toString().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(hostUserId)
                    .collection('notifications')
                    .add({
                      'message': message,
                      'roomId': widget.roomId,
                      'roomName': widget.roomName,
                      'timestamp': DateTime.now(),
                      'type': 'self_assignment',
                    });
              }

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
              final message = AppLocalizations.of(
                context,
              ).get('failedToAssign');
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text(AppLocalizations.of(context).get('error')),
                      content: Text('$message$e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocalizations.of(context).get('ok')),
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
          SnackBar(
            content: Text(
              AppLocalizations.of(context).get('hostCannotBeUnassigned'),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final message = AppLocalizations.of(context).get('removeAssignedUser');
      // Show options to remove assigned user
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: Colors.white,
              title: Text(AppLocalizations.of(context).get('removeAssignment')),
              content: Text('$message${participant['name']}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black, // black “Cancel” text
                  ),
                  child: Text(AppLocalizations.of(context).get('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red, // red background
                    foregroundColor: Colors.white, // white “Remove” text
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context).get('remove')),
                ),
              ],
            ),
      );

      if (confirm == true) {
        await _removeUserFromParticipant(participant);
      }
    } else if (_isHost && !participant['isHost']) {
      final message = AppLocalizations.of(
        context,
      ).get('removeParticipantFromRoom');
      // Show options to remove unassigned participant
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                AppLocalizations.of(context).get('removeParticipant'),
                style: TextStyle(color: Colors.black),
              ),
              content: Text(
                '$message${participant['name']}?',
                style: const TextStyle(color: Colors.black87),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    AppLocalizations.of(context).get('cancel'),
                    style: TextStyle(color: Color(0xFF1D61E7)),
                  ),
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
      final message = AppLocalizations.of(context).get('failedToRemoveUser');
      _showError('$message$e');
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
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      final dailyShifts = List<int>.from(roomDoc.data()?['dailyShifts'] ?? []);
      final updatedDoctorCount = _participants.length - 1; // After removal

      if (!_validateConsecutiveDaysShifts(dailyShifts, updatedDoctorCount)) {
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text(
                    AppLocalizations.of(context).get('cannotRemoveDoctor'),
                  ),
                  content: Text(
                    AppLocalizations.of(context).get('removeDoctorError'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context).get('ok')),
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

      // Silinen doktorun preferences'larını da sil
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('preferences')
          .doc(participant['name'])
          .delete();

      // UI'ı güncelle
      setState(() {
        _doctorPreferences.clear(); // Tüm preferences'ları temizle
      });

      // Verileri yeniden yükle
      await _refreshRoom();
      await _loadAllDoctorPreferences();
      await _loadSchedules();
    } catch (e) {
      final message = AppLocalizations.of(
        context,
      ).get('failedToRemoveParticipant');
      _showError('$message$e');
    }
  }

  Future<void> _addNewParticipant() async {
    final name = _newParticipantController.text.trim();
    if (name.isEmpty) return;

    // Prevent adding duplicate participant names
    final alreadyExists = _participants.any((p) => p['name'] == name);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).get('participantAlreadyExists'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      _participants.add({'userId': '', 'name': name, 'isHost': false});

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'participants': _participants});

      _newParticipantController.clear();
      await _refreshRoom();
    } catch (e) {
      final message = AppLocalizations.of(
        context,
      ).get('failedToAddParticipant');
      _showError('$message$e');
    }
  }

  Future<void> _deleteRoom() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text(AppLocalizations.of(context).get('deleteRoom')),
            content: Text(
              AppLocalizations.of(context).get('sureToConfirmDeleteRoom'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context).get('cancel')),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red, // 🔴 red background
                  foregroundColor: Colors.white, // white text
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(AppLocalizations.of(context).get('delete')),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .delete();

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

        for (var participant in _participants) {
          final userId = participant['userId'];
          if (userId != null && userId.toString().isNotEmpty) {
            final notificationsRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('notifications');
            final querySnapshot =
                await notificationsRef
                    .where('roomId', isEqualTo: widget.roomId)
                    .get();
            for (var doc in querySnapshot.docs) {
              await doc.reference.delete();
            }
          }
        }

        if (mounted) {
          Navigator.pop(context); // Return to home view
        }
      } catch (e) {
        final message = AppLocalizations.of(context).get('failedToDeleteRoom');
        _showError('$message$e');
      }
    }
  }

  Future<void> _shareRoomInvitation() async {
    if (!_isHost) {
      await showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(AppLocalizations.of(context).get('notAllowed')),
              content: Text(
                AppLocalizations.of(context).get('onlyHostShareInvitation'),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1D61E7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).get('ok'),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
      return;
    }

    // build the deep-link
    final inviteLink =
        'https://infoappwide.github.io/nobetimInvitation/room.html?id=${widget.roomId}';

    // copy to clipboard
    await Clipboard.setData(ClipboardData(text: inviteLink));

    if (!mounted) return;

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.white, // set white background
            title: Text(AppLocalizations.of(context).get('invitationLink')),
            content: Text(AppLocalizations.of(context).get('linkCopied')),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1D61E7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context).get('ok'),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
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

  String _getWeekTitle(Map<String, List<Map<String, String>>> weekSchedule) {
    final dates =
        weekSchedule.keys.toList()..sort((a, b) {
          final aDate = DateTime.parse(a.split('.').reversed.join('-'));
          final bDate = DateTime.parse(b.split('.').reversed.join('-'));
          return aDate.compareTo(bDate);
        });

    if (dates.isEmpty) return '';
    final firstDate = dates.first;
    final lastDate = dates.last;
    return '$firstDate - $lastDate';
  }

  Future<void> _showTotalShiftsDialog() async {
    // Calculate total shifts for each participant
    Map<String, int> totalShifts = {};

    // Initialize all participants with 0 shifts
    for (var participant in _participants) {
      totalShifts[participant['name']] = 0;
    }

    // Count shifts from schedule
    if (_appliedSchedule != null) {
      _appliedSchedule!.forEach((date, assignments) {
        for (var assignment in assignments) {
          String doctorName = assignment['name'] ?? '';
          totalShifts[doctorName] = (totalShifts[doctorName] ?? 0) + 1;
        }
      });
    }

    // Show dialog with results
    if (mounted) {
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                AppLocalizations.of(context).get('totalShiftsPerDoctor'),
                style: TextStyle(color: Colors.black),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      totalShifts.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D61E7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  entry.value.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1D61E7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).get('close'),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (_appliedSchedule == null || _appliedSchedule!.isEmpty) {
        _showError(AppLocalizations.of(context).get('noScheduleToExport'));
        return;
      }

      final excel = excel_import.Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Create cell styles for alternating rows
      final blueStyle = excel_import.CellStyle(
        backgroundColorHex: '#1D61E7',
        fontColorHex: '#FFFFFF',
        bold: true, // Make text bold for better visibility on blue
      );

      final whiteStyle = excel_import.CellStyle(
        backgroundColorHex: '#FFFFFF',
        fontColorHex: '#1D61E7',
        bold: true, // Keep text bold for consistency
      );

      // Sort dates chronologically
      final dates =
          _appliedSchedule!.keys.toList()..sort((a, b) {
            final aDate = DateTime.parse(a.split('.').reversed.join('-'));
            final bDate = DateTime.parse(b.split('.').reversed.join('-'));
            return aDate.compareTo(bDate);
          });

      // Find the maximum number of doctors assigned on any day
      int maxDoctorsPerDay = 0;
      for (var date in dates) {
        final assignments = _appliedSchedule![date]!;
        if (assignments.length > maxDoctorsPerDay) {
          maxDoctorsPerDay = assignments.length;
        }
      }

      int dateColumnWidth =
          'DD.MM.YYYY'.length; // Minimum width for date column
      int doctorColumnWidth =
          'Doctor Name'.length; // Minimum width for doctor names

      // First pass: calculate column widths
      for (var rowIndex = 0; rowIndex < dates.length; rowIndex++) {
        final date = dates[rowIndex];
        if (date.length > dateColumnWidth) dateColumnWidth = date.length;

        final assignments = _appliedSchedule![date]!;
        final sortedAssignments = List<Map<String, String>>.from(assignments)
          ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

        for (
          var colIndex = 0;
          colIndex < sortedAssignments.length;
          colIndex++
        ) {
          final doctorName = sortedAssignments[colIndex]['name'] ?? '';
          if (doctorName.length > doctorColumnWidth) {
            doctorColumnWidth = doctorName.length;
          }
        }
      }

      // Second pass: write data with calculated widths and styles

      for (var rowIndex = 0; rowIndex < dates.length; rowIndex++) {
        final date = dates[rowIndex];
        final currentStyle = rowIndex % 2 == 0 ? blueStyle : whiteStyle;

        try {
          // Write date in first column
          final dateCell = sheet.cell(
            excel_import.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: rowIndex,
            ),
          );
          dateCell.value = date;
          dateCell.cellStyle = currentStyle;
          sheet.setColWidth(0, dateColumnWidth.toDouble() + 2);

          // Get and sort assignments for this date
          final assignments = _appliedSchedule![date]!;
          final sortedAssignments = List<Map<String, String>>.from(assignments)
            ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

          // Write doctor names and add empty cells with style for remaining columns
          for (var colIndex = 0; colIndex < maxDoctorsPerDay; colIndex++) {
            final cell = sheet.cell(
              excel_import.CellIndex.indexByColumnRow(
                columnIndex: colIndex + 1,
                rowIndex: rowIndex,
              ),
            );

            if (colIndex < sortedAssignments.length) {
              cell.value = sortedAssignments[colIndex]['name'] ?? '';
            } else {
              cell.value = ''; // Empty cell but with style
            }

            cell.cellStyle = currentStyle;
            sheet.setColWidth(colIndex + 1, doctorColumnWidth.toDouble() + 2);
          }
        } catch (e) {
          print('Error processing row $rowIndex: $e');
          continue; // Skip problematic row and continue with next
        }
      }

      // Save and share file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${widget.roomName}_schedule_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      try {
        await file.writeAsBytes(excel.encode() ?? []);
        await Share.shareXFiles([
          XFile(filePath),
        ], subject: '${widget.roomName} Schedule');
      } catch (e) {
        _showError(
          '${AppLocalizations.of(context).get('failedToSaveExcel')}: $e',
        );
        return;
      }
    } catch (e) {
      _showError(
        '${AppLocalizations.of(context).get('failedToExportSchedule')}: $e',
      );
    }
  }

  Widget _buildScheduleList(Map<String, List<Map<String, String>>>? schedule) {
    if (schedule == null) return const SizedBox.shrink();

    // — 1) Figure out "All" vs "Me" data —
    final fallbackName = AppLocalizations.of(context).translate('unknown');

    final currentParticipant = _participants.firstWhere(
      (p) => p['userId'] == widget.currentUserId,
      orElse: () => {'name': fallbackName}, // Provide fallback
    );
    final myName = currentParticipant['name'] as String;
    final filteredSchedule =
        _showOnlyMySchedule
            ? Map.fromEntries(
              schedule.entries.where(
                (entry) => entry.value.any((a) => a['name'] == myName),
              ),
            )
            : schedule;

    // — 2) Build week groups only if we have data to show —
    final displaySchedule = filteredSchedule;
    final weeklySchedule = <int, Map<String, List<Map<String, String>>>>{};
    if (displaySchedule.isNotEmpty) {
      final sortedDates =
          displaySchedule.keys.toList()..sort((a, b) {
            final da = DateTime.parse(a.split('.').reversed.join('-'));
            final db = DateTime.parse(b.split('.').reversed.join('-'));
            return da.compareTo(db);
          });
      final firstDate = DateTime.parse(
        sortedDates.first.split('.').reversed.join('-'),
      );
      for (var date in sortedDates) {
        final dt = DateTime.parse(date.split('.').reversed.join('-'));
        final weekIndex = dt.difference(firstDate).inDays ~/ 7;
        weeklySchedule.putIfAbsent(weekIndex, () => {})[date] =
            displaySchedule[date]!;
      }
    }

    // — 3) Render —
    return Column(
      children: [
        // 3a) Toggle row
        Row(
          children: [
            ElevatedButton(
              onPressed: _showTotalShiftsDialog,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                shape: StadiumBorder(),
                backgroundColor: Color(0xFF1D61E7),
              ),
              child: Text(AppLocalizations.of(context).get('totalShifts')),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _showOnlyMySchedule = false),
              child: Text(
                AppLocalizations.of(context).get('all'),
                style: TextStyle(
                  color:
                      !_showOnlyMySchedule ? Color(0xFF1D61E7) : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showOnlyMySchedule = true),
              child: Text(
                AppLocalizations.of(context).get('me'),
                style: TextStyle(
                  color: _showOnlyMySchedule ? Color(0xFF1D61E7) : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 8),
        // 3b) The blue schedule box
        Container(
          height: 300,
          width: double.infinity, // optional but helps stretch background
          decoration: BoxDecoration(
            color: const Color(0xFF1D61E7),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              _showOnlyMySchedule && displaySchedule.isEmpty
                  ? Center(
                    child: Text(
                      AppLocalizations.of(context).get('doNotHaveDuty'),
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  )
                  // 3b-ii) Otherwise your existing PageView:
                  : PageView.builder(
                    controller: _pageController,
                    itemCount: weeklySchedule.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, weekIndex) {
                      final weekMap = weeklySchedule[weekIndex]!;
                      return Column(
                        children: [
                          // Week header with arrows
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                if (weekIndex > 0)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_left,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => _handlePageChange(-1),
                                  ),
                                Expanded(
                                  child: Text(
                                    _getWeekTitle(weekMap),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (weekIndex < weeklySchedule.length - 1)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_right,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => _handlePageChange(1),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(
                            color: Colors.white,
                            thickness: 1,
                            height: 16,
                          ),

                          // Day‐by‐day list
                          Expanded(
                            child: ListView.builder(
                              itemCount: weekMap.length,
                              itemBuilder: (context, dayIndex) {
                                final date = weekMap.keys.toList()[dayIndex];
                                final assignments = weekMap[date]!;
                                final parts = date.split('.');
                                final dt = DateTime(
                                  int.parse(parts[2]),
                                  int.parse(parts[1]),
                                  int.parse(parts[0]),
                                );
                                final weekdayNames = [
                                  AppLocalizations.of(context).get('monday'),
                                  AppLocalizations.of(context).get('tuesday'),
                                  AppLocalizations.of(context).get('wednesday'),
                                  AppLocalizations.of(context).get('thursday'),
                                  AppLocalizations.of(context).get('friday'),
                                  AppLocalizations.of(context).get('saturday'),
                                  AppLocalizations.of(context).get('sunday'),
                                ];

                                return Column(
                                  children: [
                                    ListTile(
                                      title: Row(
                                        children: [
                                          Text(
                                            '$date ${weekdayNames[dt.weekday - 1]}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (_isHost) const Spacer(),
                                          if (_isHost)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add,
                                                color: Colors.white,
                                              ),
                                              onPressed:
                                                  () =>
                                                      _showAddAssignmentDialog(
                                                        date,
                                                      ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children:
                                            assignments.map((a) {
                                              return _isHost
                                                  ? Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '${a['name']}',
                                                          style: const TextStyle(
                                                            color:
                                                                Colors.white70,
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
                                                            () =>
                                                                _removeAssignment(
                                                                  date,
                                                                  a,
                                                                ),
                                                      ),
                                                    ],
                                                  )
                                                  : Text(
                                                    '${a['name']}',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                  );
                                            }).toList(),
                                      ),
                                    ),
                                    if (dayIndex < weekMap.length - 1)
                                      const Divider(
                                        color: Colors.white24,
                                        height: 1,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
        ),
        // Export button below schedule
        if (_appliedSchedule != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: ElevatedButton.icon(
              onPressed: _exportToExcel,
              icon: Icon(Icons.download, size: 20, color: Colors.white),
              label: Text(
                AppLocalizations.of(context).get('exportExcel'),
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1D61E7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
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
        final message = AppLocalizations.of(
          context,
        ).get('failedToRemoveAssignment');
        _showError('$message$e');
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
    final selectedParticipant = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(
              '$message\n\n$date',
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
        final message = AppLocalizations.of(
          context,
        ).get('failedToAddAssignment');
        _showError('$message$e');
      }
    }
  }

  Future<void> _openSetDutiesScreen(
    Map<String, dynamic> participant,
    int index,
  ) async {
    try {
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        _showError(AppLocalizations.of(context).get('roomDataNotFound'));
        return;
      }

      final data = roomDoc.data();
      if (data == null ||
          !data.containsKey('firstDay') ||
          !data.containsKey('lastDay')) {
        _showError(AppLocalizations.of(context).get('roomDataIncomplete'));
        return;
      }

      final firstDayStr = data['firstDay'] as String;
      final lastDayStr = data['lastDay'] as String;

      final firstDay = DateTime.parse(firstDayStr);
      final lastDay = DateTime.parse(lastDayStr);

      final normalizedFirstDay = DateTime(
        firstDay.year,
        firstDay.month,
        firstDay.day,
      );
      final normalizedLastDay = DateTime(
        lastDay.year,
        lastDay.month,
        lastDay.day,
        23,
        59,
        59,
      );

      if (mounted) {
        final result = await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder:
                (_, __, ___) => SetDutiesView(
                  roomId: widget.roomId,
                  userId: widget.currentUserId,
                  doctorName: participant['name'],
                  doctorIndex: index,
                  firstDay: normalizedFirstDay,
                  lastDay: normalizedLastDay,
                ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );

        if (result != null && mounted) {
          setState(() {
            _doctorPreferences[index] = {
              'shiftsCount': result['shiftsCount'],
              'availability': result['availability'],
            };
          });
        }
      }
    } catch (e) {
      final message = AppLocalizations.of(
        context,
      ).get('failedToOpenDutiesScreen');
      _showError('$message$e');
    }
  }

  Future<void> _editDailyShifts() async {
    final roomDoc =
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .get();

    if (!roomDoc.exists) {
      _showError(AppLocalizations.of(context).get('roomDataNotFound'));
      return;
    }

    final data = roomDoc.data()!;
    final List<int> currentDailyShifts = List<int>.from(data['dailyShifts']);
    final String firstDay = data['firstDay'];

    final allDaysController = TextEditingController(text: '0');
    final List<TextEditingController> dayControllers = List.generate(
      currentDailyShifts.length,
      (i) => TextEditingController(text: currentDailyShifts[i].toString()),
    );

    // --- show the dialog ----------------------------------------------------------------
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true, // tap-outside just closes it
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(AppLocalizations.of(context).get('editDailyShifts')),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // “apply to all” row --------------------------------------------------
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).get('setAllDaysTo'),
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              controller: allDaysController,
                              cursorColor: Colors.black,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              final value =
                                  int.tryParse(allDaysController.text) ?? 0;
                              for (final c in dayControllers) {
                                c.text = value.toString();
                              }
                              setStateDialog(() {});
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF1D61E7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context).get('apply'),
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32),
                    // per-day list --------------------------------------------------------
                    Expanded(
                      child: ListView.builder(
                        itemCount: dayControllers.length,
                        itemBuilder: (context, index) {
                          final date = DateTime.parse(
                            firstDay,
                          ).add(Duration(days: index));
                          final dateStr =
                              '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dateStr,
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: TextFormField(
                                    controller: dayControllers[index],
                                    cursorColor: Colors.black,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.black,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.black,
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // cancel – do nothing ----------------------------------------------------
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    AppLocalizations.of(context).get('cancel'),
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                // confirm – save ---------------------------------------------------------
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1D61E7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).get('change'),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // user dismissed dialog without pressing “Change”
    if (confirmed != true) return;

    // --- apply the updates --------------------------------------------------------------
    final updatedShifts = <int>[];
    for (final c in dayControllers) {
      updatedShifts.add(int.tryParse(c.text) ?? 0);
    }

    if (!_validateConsecutiveDaysShifts(updatedShifts, _participants.length)) {
      await showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              backgroundColor: Colors.white,
              title: Text(AppLocalizations.of(context).get('invalidShifts')),
              content: Text(
                AppLocalizations.of(context).get('consecutiveDaysError'),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1D61E7),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).get('ok'),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({'dailyShifts': updatedShifts});

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text(AppLocalizations.of(context).get('shiftsUpdated')),
            content: Text(
              AppLocalizations.of(context).get('shiftsUpdatedSuccessfully'),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1D61E7),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context).get('ok'),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _editRoomDates() async {
    try {
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        _showError(AppLocalizations.of(context).get('roomDataNotFound'));
        return;
      }
      final bool? shouldProceed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: Colors.white,
              title: Text(AppLocalizations.of(context).get('warning')),
              content: Text(
                AppLocalizations.of(context).get('changingRoomDatesWarning'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(AppLocalizations.of(context).get('cancel')),
                  style: TextButton.styleFrom(foregroundColor: Colors.black),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    backgroundColor: Color(0xFF1D61E7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).get('continue'),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );

      if (shouldProceed != true) return;

      final data = roomDoc.data()!;
      final firstDay = DateTime.parse(data['firstDay'] as String);
      final lastDay = DateTime.parse(data['lastDay'] as String);

      final result = await showDialog<Map<String, DateTime>>(
        context: context,
        builder:
            (context) => Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF1D61E7),
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: Colors.black),
                ),
                dialogBackgroundColor: Colors.white,
                textSelectionTheme: const TextSelectionThemeData(
                  cursorColor: Colors.black,
                  selectionColor: Colors.black12,
                  selectionHandleColor: Colors.black,
                ),
                inputDecorationTheme: const InputDecorationTheme(
                  labelStyle: TextStyle(color: Colors.black),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  hintStyle: TextStyle(color: Colors.black),
                ),
              ),
              child: DateEditorDialog(firstDay: firstDay, lastDay: lastDay),
            ),
      );

      if (result != null) {
        final newFirstDay =
            '${result['firstDay']!.year}-${result['firstDay']!.month.toString().padLeft(2, '0')}-${result['firstDay']!.day.toString().padLeft(2, '0')}';
        final newLastDay =
            '${result['lastDay']!.year}-${result['lastDay']!.month.toString().padLeft(2, '0')}-${result['lastDay']!.day.toString().padLeft(2, '0')}';

        final daysDifference =
            result['lastDay']!.difference(result['firstDay']!).inDays + 1;
        final List<int> newDailyShifts = List.filled(daysDifference, 1);

        if (mounted) {
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
        }

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({
              'firstDay': newFirstDay,
              'lastDay': newLastDay,
              'dailyShifts': newDailyShifts,
            });

        final batch = FirebaseFirestore.instance.batch();
        final preferencesSnapshot =
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .collection('preferences')
                .get();
        for (var doc in preferencesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        setState(() {
          _doctorPreferences.clear();
        });

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({'appliedSchedule': null});

        final hostParticipant = _participants.firstWhere(
          (p) => p['isHost'] == true,
          orElse: () => <String, dynamic>{},
        );
        final hostUserId = hostParticipant['userId'];
        final roomName = widget.roomName;
        final now = DateTime.now();

        final assignedUsers = _participants.where(
          (p) =>
              p['userId'] != null &&
              p['userId'].toString().isNotEmpty &&
              p['isHost'] != true,
        );

        for (final user in assignedUsers) {
          final userId = user['userId'];
          if (userId != null && userId.toString().isNotEmpty) {
            final message = AppLocalizations.of(context).translate(
              'yourHostUpdatedStartEndDates',
              params: {'roomName': roomName},
            );

            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('notifications')
                .add({
                  'message': message,
                  'roomId': widget.roomId,
                  'roomName': roomName,
                  'timestamp': now,
                  'type': 'room_dates_updated',
                });
          }
        }

        if (hostUserId != null && hostUserId.toString().isNotEmpty) {
          final message = AppLocalizations.of(context).translate(
            'youUpdatedStartEndDates',
            params: {'roomName': roomName},
          );

          await FirebaseFirestore.instance
              .collection('users')
              .doc(hostUserId)
              .collection('notifications')
              .add({
                'message': message,
                'roomId': widget.roomId,
                'roomName': roomName,
                'timestamp': now,
                'type': 'room_dates_updated_host',
              });
        }

        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        // Show white popup instead of snackbar
        if (mounted) {
          await showDialog(
            context: context,
            builder:
                (_) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text(AppLocalizations.of(context).get('roomUpdated')),
                  content: Text(
                    AppLocalizations.of(context).get('roomDatesUpdated'),
                  ),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Color(0xFF1D61E7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        AppLocalizations.of(context).get('ok'),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          );
        }

        await _refreshRoom();
        await _loadAllDoctorPreferences();
        await _loadSchedules();
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      final message = AppLocalizations.of(
        context,
      ).get('failedToUpdateRoomDates');
      _showError('$message$e');
    }
  }

  Future<void> _handlePreviewSchedule() async {
    final roomDoc =
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .get();

    if (!roomDoc.exists) {
      _showError(AppLocalizations.of(context).get('roomDataNotFound'));
      return;
    }

    final data = roomDoc.data();
    final firstDay = DateTime.parse(data?['firstDay'] as String);
    final lastDay = DateTime.parse(data?['lastDay'] as String);
    final dailyShifts = List<int>.from(data?['dailyShifts'] ?? []);
    final defaultShifts = data?['defaultShifts'] ?? 0;

    final numDays = lastDay.difference(firstDay).inDays + 1;

    // Find the doctor with the most shifts
    final maxShiftsEntry = _participants
        .map((participant) {
          final shiftsCount =
              _doctorPreferences[_participants.indexOf(
                participant,
              )]?['shiftsCount'] ??
              defaultShifts;
          return {'name': participant['name'], 'shiftsCount': shiftsCount};
        })
        .reduce((a, b) => a['shiftsCount'] > b['shiftsCount'] ? a : b);

    final maxShifts = maxShiftsEntry['shiftsCount'];
    final maxShiftsDoctorName = maxShiftsEntry['name'];

    if (numDays < maxShifts * 2) {
      final message = AppLocalizations.of(context).get('invalidScheduleError');
      final numOfDays = AppLocalizations.of(context).get('numberOfDays');
      final doctorWithMostShifts = AppLocalizations.of(
        context,
      ).get('doctorWithMostShifts');
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                AppLocalizations.of(context).get('invalidSchedule'),
                style: TextStyle(color: Colors.black),
              ),
              content: Text(
                '$message\n\n'
                '$numOfDays$numDays\n\n'
                '$doctorWithMostShifts$maxShiftsDoctorName ($maxShifts)',
                style: const TextStyle(color: Colors.black87),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1D61E7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).get('ok'),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
      return;
    }

    // Calculate total shifts
    final totalDoctorShifts = _participants.fold<int>(
      0,
      (sum, participant) =>
          sum +
          ((_doctorPreferences[_participants.indexOf(
                    participant,
                  )]?['shiftsCount'] ??
                  defaultShifts)
              as int),
    );
    final totalDailyShifts = dailyShifts.fold<int>(
      0,
      (sum, shifts) => sum + shifts,
    );

    if (totalDoctorShifts < totalDailyShifts) {
      final message = AppLocalizations.of(context).get('invalidScheduleError2');
      final totalShifts = AppLocalizations.of(context).get('totalDoctorShifts');
      final totalRequiredShifts = AppLocalizations.of(
        context,
      ).get('totalDailyShifts');
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                AppLocalizations.of(context).get('invalidSchedule'),
                style: TextStyle(color: Colors.black),
              ),
              content: Text(
                '$message\n\n'
                '$totalShifts$totalDoctorShifts\n\n'
                '$totalRequiredShifts$totalDailyShifts',
                style: const TextStyle(color: Colors.black87),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1D61E7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).get('ok'),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      },
    );

    try {
      // Filter participants to get only doctors (non-host users)
      final doctors =
          _participants
              .asMap()
              .entries
              .map((entry) => entry.value['name'] as String)
              .toList();

      if (doctors.isEmpty) {
        Navigator.pop(context);
        _showError(AppLocalizations.of(context).get('noDoctorsFound'));
        return;
      }

      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      final data = roomDoc.data();
      final firstDay = data?['firstDay'] as String;
      final lastDay = data?['lastDay'] as String;
      final dailyShifts = List<int>.from(data?['dailyShifts'] ?? []);
      final defaultShifts = data?['defaultShifts'] ?? 0; // <-- EKLENDİ

      // Prepare the input data with doctors from participants
      final numShifts = List<int>.generate(
        doctors.length,
        (i) =>
            _doctorPreferences[i]?['shiftsCount'] ??
            defaultShifts, // <-- 10 yerine defaultShifts
      );

      final availabilityMatrix = List<List<int>>.generate(doctors.length, (i) {
        final prefs = _doctorPreferences[i];
        final List<int> availability =
            (prefs?['availability'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            List<int>.filled(dailyShifts.length, 0);
        print('Doctor ${doctors[i]} (index $i) availability: $availability');
        return availability;
      });

      final inputData = {
        'firstDay': firstDay,
        'lastDay': lastDay,
        'doctors': doctors,
        'numShifts': numShifts,
        'dailyShifts': dailyShifts,
        'availabilityMatrix': availabilityMatrix,
      };

      print('Algorithm Input Data:');
      print('Doctors order: $doctors'); // Debug print
      print('Number of Shifts per Doctor: $numShifts'); // Debug print
      print('Daily Required Shifts: $dailyShifts');
      print('Availability Matrix: $availabilityMatrix'); // Debug print

      // Make API request
      final response = await http.post(
        Uri.parse(
          'https://django-cplex-app-156171440096.europe-west1.run.app/api/generate-schedule/',
        ),
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

        AdHelper.maybeShowRewardedAd(
          chancePercent: 100,
          onRewardEarned: () {
            print("Kullanıcı ödüllü videoyu tamamladı!");
            // İstersen ekstra hak vs tanımlayabilirsin
          },
        );

        final result = await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder:
                (_, __, ___) => PreviewScheduleView(
                  participants: _participants,
                  roomId: widget.roomId,
                  scheduleData: schedule,
                ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );

        // If returned with refresh flag, reload the data
        if (result == true) {
          await _loadSchedules();
          await _refreshRoom();
        }
      } else {
        final message = AppLocalizations.of(
          context,
        ).get('failedToFetchSchedule');
        Navigator.pop(context); // Remove loading dialog
        _showError('$message${response.body}');
      }
    } catch (e) {
      final message = AppLocalizations.of(
        context,
      ).get('errorOccurredWithError');
      Navigator.pop(context); // Remove loading dialog
      _showError('$message$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0x1E1E1E),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadSchedules();
              await _refreshRoom();
              await _loadAllDoctorPreferences();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        Container(
                          margin: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) => HomeView(),
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration: Duration.zero,
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                          ),
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
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                            color: Colors.white,
                            onSelected: (choice) async {
                              switch (choice) {
                                case 'editShifts':
                                  _editDailyShifts();
                                  break;
                                case 'editDates':
                                  _editRoomDates();
                                  break;
                                case 'share':
                                  _shareRoomInvitation();
                                  break;
                                case 'preview':
                                  await _handlePreviewSchedule();
                                  break;
                                case 'delete':
                                  _deleteRoom();
                                  break;
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  if (_isScheduleApplied)
                                    PopupMenuItem(
                                      value: 'preview',
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.preview,
                                          color: Colors.black,
                                        ),
                                        title: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).get('previewNewSchedule'),
                                        ),
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 'editShifts',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.work_history,
                                        color: Colors.black,
                                      ),
                                      title: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).get('editDailyShifts'),
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'editDates',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.calendar_month,
                                        color: Colors.black,
                                      ),
                                      title: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).get('editRoomDates'),
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'share',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.share,
                                        color: Colors.black,
                                      ),
                                      title: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).get('shareInvitation'),
                                      ),
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      title: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).get('deleteRoom'),
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ],
                          ),
                        if (!_isHost) const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // --- One card: date range at top, description below -----------------
                    FutureBuilder<DocumentSnapshot>(
                      future: _roomDocFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D61E7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const SizedBox(height: 32);
                        }

                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final firstDayStr = data['firstDay'] ?? '';
                        final lastDayStr = data['lastDay'] ?? '';
                        final _weekdayNames = [
                          AppLocalizations.of(context).get('mon'),
                          AppLocalizations.of(context).get('tue'),
                          AppLocalizations.of(context).get('wed'),
                          AppLocalizations.of(context).get('thu'),
                          AppLocalizations.of(context).get('fri'),
                          AppLocalizations.of(context).get('sat'),
                          AppLocalizations.of(context).get('sun'),
                        ];

                        DateTime? fd, ld;
                        try {
                          fd = DateTime.parse(firstDayStr);
                          ld = DateTime.parse(lastDayStr);
                        } catch (_) {}

                        // build the display strings
                        final firstDisplay =
                            fd != null
                                ? '${_weekdayNames[fd.weekday - 1]} $firstDayStr'
                                : firstDayStr;
                        final lastDisplay =
                            ld != null
                                ? '${_weekdayNames[ld.weekday - 1]} $lastDayStr'
                                : lastDayStr;

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1D61E7,
                            ), // unified blue background
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // top row: “first - last”
                              Text(
                                '$firstDisplay  /  $lastDisplay',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Divider(
                                color: Colors.white54,
                                thickness: 1,
                              ),
                              const SizedBox(height: 4),

                              // room description
                              Text(
                                widget.roomDescription,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 10),
                    if (_appliedSchedule != null)
                      _buildScheduleList(_appliedSchedule),
                    const SizedBox(height: 16),
                    if (_isHost && !_isScheduleApplied)
                      ElevatedButton(
                        onPressed: _handlePreviewSchedule,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1D61E7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(
                            context,
                          ).get('previewNewSchedule'),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        AppLocalizations.of(context).get('participantsTitle'),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isHost)
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _newParticipantController,
                                    style: const TextStyle(color: Colors.white),
                                    cursorColor: const Color(0xFF1D61E7),
                                    decoration: InputDecoration(
                                      hintText: AppLocalizations.of(
                                        context,
                                      ).get('addParticipant'),
                                      hintStyle: TextStyle(
                                        color: Colors.white60,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white60,
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFF1D61E7),
                                          width: 2,
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
      ),
    );
  }

  Widget _buildParticipantRow(String name, Color statusColor) {
    final participant = _participants.firstWhere(
      (p) => p['name'] == name,
      orElse: () => <String, dynamic>{},
    );

    bool isHost = participant['isHost'] == true;
    String? assignedUserName = participant['assignedUserName'];
    final index = _participants.indexWhere((p) => p['name'] == name);
    final hasPreferences = _doctorPreferences.containsKey(index);
    final isCurrentUser = participant['userId'] == widget.currentUserId;

    final hostText = AppLocalizations.of(context).get('host');
    final assignedToText = AppLocalizations.of(context).get('assignedTo');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border:
            isHost ? Border.all(color: Color(0xFF1D61E7), width: 3.0) : null,
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
          const Icon(Icons.person, color: Color(0xFF1D61E7)),
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
                    '${isHost ? hostText : ""}${isHost && assignedUserName != null ? " • " : ""}${assignedUserName != null ? "$assignedToText$assignedUserName" : ""}',
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
          if (participant['userId']?.isNotEmpty == true)
            TextButton(
              onPressed:
                  isCurrentUser
                      ? () => _openSetDutiesScreen(participant, index)
                      : () async {
                        // Changed to async
                        // Get room document to get dates and defaults
                        final roomDoc =
                            await FirebaseFirestore.instance
                                .collection('rooms')
                                .doc(widget.roomId)
                                .get();

                        if (!roomDoc.exists) return;

                        final data = roomDoc.data()!;
                        final defaultShiftsRoom = data['defaultShifts'] ?? 0;
                        final firstDayStr = data['firstDay'] as String;
                        final lastDayStr = data['lastDay'] as String;
                        final totalDays =
                            DateTime.parse(
                              lastDayStr,
                            ).difference(DateTime.parse(firstDayStr)).inDays +
                            1;

                        // If no preferences exist, create default ones
                        Map<String, dynamic> preferences;
                        if (!hasPreferences) {
                          preferences = {
                            'shiftsCount': defaultShiftsRoom,
                            'availability': List<int>.filled(totalDays, 0),
                            'firstDay': firstDayStr,
                            'lastDay': lastDayStr,
                          };

                          // Save these default preferences
                          await FirebaseFirestore.instance
                              .collection('rooms')
                              .doc(widget.roomId)
                              .collection('preferences')
                              .doc(participant['name'])
                              .set({
                                'shiftsCount': defaultShiftsRoom,
                                'availability': List<int>.filled(totalDays, 0),
                              });

                          // Update local preferences
                          setState(() {
                            _doctorPreferences[index] = preferences;
                          });
                        } else {
                          preferences = _doctorPreferences[index]!;
                        }

                        // Navigate to view preferences
                        if (mounted) {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (_, __, ___) => ViewPreferencesView(
                                    doctorName: participant['name'],
                                    preferences: preferences,
                                    isHost: _isHost,
                                    roomId: widget.roomId,
                                  ),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          ).then((result) async {
                            if (result != null) {
                              await _loadAllDoctorPreferences();
                              setState(() {});
                            }
                          });
                        }
                      },
              child: Text(
                isCurrentUser
                    ? hasPreferences
                        ? AppLocalizations.of(context).get('editDuties')
                        : AppLocalizations.of(context).get('setDuties')
                    : AppLocalizations.of(context).get('viewDuties'),
                style: TextStyle(color: Color(0xFF1D61E7)),
              ),
            )
          else if (_isHost && !participant['isHost'])
            TextButton(
              onPressed: () async {
                final roomDoc =
                    await FirebaseFirestore.instance
                        .collection('rooms')
                        .doc(widget.roomId)
                        .get();
                if (!roomDoc.exists) return;

                final data = roomDoc.data()!;
                final defaultShiftsRoom = data['defaultShifts'] ?? 0;
                final firstDayStr = data['firstDay'] as String;
                final lastDayStr = data['lastDay'] as String;
                final totalDays =
                    DateTime.parse(
                      lastDayStr,
                    ).difference(DateTime.parse(firstDayStr)).inDays +
                    1;

                final prefDoc =
                    await FirebaseFirestore.instance
                        .collection('rooms')
                        .doc(widget.roomId)
                        .collection('preferences')
                        .doc(participant['name'])
                        .get();

                final shiftsCount =
                    prefDoc.exists
                        ? (prefDoc.data()?['shiftsCount'] as int? ??
                            defaultShiftsRoom)
                        : defaultShiftsRoom;

                final availability =
                    prefDoc.exists
                        ? List<int>.from(prefDoc.data()?['availability'] ?? [])
                        : List<int>.filled(totalDays, 0);

                final defaultPrefs = {
                  'shiftsCount': shiftsCount,
                  'availability': availability,
                  'firstDay': firstDayStr,
                  'lastDay': lastDayStr,
                };

                Navigator.of(context)
                    .push(
                      PageRouteBuilder(
                        pageBuilder:
                            (_, __, ___) => ViewPreferencesView(
                              doctorName: participant['name'],
                              preferences: defaultPrefs,
                              isHost: true,
                              roomId: widget.roomId,
                            ),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    )
                    .then((result) async {
                      if (result != null) {
                        setState(() {
                          _doctorPreferences[_participants.indexOf(
                            participant,
                          )] = {
                            'shiftsCount': result['shiftsCount'],
                            'availability': result['availability'],
                            'firstDay': firstDayStr,
                            'lastDay': lastDayStr,
                          };
                        });
                      }
                    });
              },
              child: Text(
                AppLocalizations.of(context).get('setShifts'),
                style: TextStyle(color: Color(0xFF1D61E7)),
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
