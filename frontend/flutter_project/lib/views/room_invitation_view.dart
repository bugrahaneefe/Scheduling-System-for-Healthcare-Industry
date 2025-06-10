import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project491/utils/app_localizations.dart';
import 'package:project491/views/home_view.dart';
import '../managers/auth_services.dart';
import 'room_view.dart';

class RoomInvitationView extends StatefulWidget {
  final String roomId;
  final bool returnToHome; // Add this parameter

  const RoomInvitationView({
    Key? key,
    required this.roomId,
    this.returnToHome = false, // Default to false for backward compatibility
  }) : super(key: key);

  @override
  State<RoomInvitationView> createState() => _RoomInvitationViewState();
}

class _RoomInvitationViewState extends State<RoomInvitationView> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _roomData;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load room data
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        setState(() {
          _error = AppLocalizations.of(context).get('roomNotFound');
          _isLoading = false;
        });
        return;
      }

      // Load user data
      final currentUserId = authService.value.currentUser?.uid;
      if (currentUserId != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .get();

        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data();
            _roomData = roomDoc.data();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context).get('failedToLoadData');
        _isLoading = false;
      });
    }
  }

  void _navigateToRoom(String currentUserId) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => RoomView(
          roomId: widget.roomId,
          roomName: _roomData?['name'] ?? '',
          roomDescription: _roomData?['description'] ?? '',
          participants: List<Map<String, dynamic>>.from(_roomData?['participants'] ?? []),
          currentUserId: currentUserId,
        ),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  Future<void> _joinRoom() async {
    setState(() => _isLoading = true);

    try {
      final currentUserId = authService.value.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is already in the room
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();

      if (userDoc.data()?['rooms']?.contains(widget.roomId) ?? false) {
        if (mounted) {
          _showAlreadyAssignedDialog(); // Use the dialog here
          setState(() => _isLoading = false);
          return;
        }
      }

      // Check if participant is already assigned
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();
      
      final participants = List<Map<String, dynamic>>.from(roomDoc.data()?['participants'] ?? []);
      final assignedParticipant = participants.firstWhere(
        (p) => p['userId'] == currentUserId,
        orElse: () => <String, dynamic>{},
      );

      if (assignedParticipant.isNotEmpty) {
        if (mounted) {
          _showParticipantAssignedDialog(assignedParticipant['name']); // Use the dialog here
          setState(() => _isLoading = false);
          return;
        }
      }

      // Add room to user's rooms array
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
            'rooms': FieldValue.arrayUnion([widget.roomId]),
          });

      if (mounted) {
        _navigateToRoom(currentUserId);
      }
    } catch (e) {
      final message = AppLocalizations.of(context).get('failedToJoinRoom');
      setState(() {
        _error = '$message$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = AppLocalizations.of(context).get('joinRoom');
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : _error != null
                  ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                  : Column(
                    children: [
                      // User info card at the top
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D61E7), // Changed to blue background
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white, // Changed to white icon
                              size: 36,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context).get('joiningAs'),
                                    style: TextStyle(
                                      color: Colors.white, // Changed to white text
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userData?['name'] ?? AppLocalizations.of(context).get('unknownUser'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _userData?['title'] ?? AppLocalizations.of(context).get('noTitle'),
                                    style: TextStyle(
                                      color: Colors.white70, // Changed to semi-transparent white
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Rest of the invitation content
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$message${_roomData?['name'] ?? AppLocalizations.of(context).get('unknownRoom')}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _roomData?['description'] ?? AppLocalizations.of(context).get('noDescription'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton(
                                onPressed: _joinRoom,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D61E7), // Changed to blue background
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      )
                                    : Text(
                                        AppLocalizations.of(context).get('joinRoom'),
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white, // Changed to white text
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (context) => const HomeView()),
                                    (route) => false
                                  );
                                },
                                child: Text(
                                  AppLocalizations.of(context).get('cancel'),
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  void _showParticipantAssignedDialog(String participantName) {
    final message = AppLocalizations.of(context).get('participantAssignedTo');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          AppLocalizations.of(context).get('participantAssigned'),
          style: TextStyle(color: Colors.black),
        ),
        content: Text(
          '$message$participantName.',
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
            child: Text(AppLocalizations.of(context).get('ok'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAlreadyAssignedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            child: Text(AppLocalizations.of(context).get('ok'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
