import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../managers/auth_services.dart';

class CreateRoomSheet extends StatefulWidget {
  final String hostId;
  final String hostName;

  const CreateRoomSheet({
    Key? key,
    required this.hostId,
    required this.hostName,
  }) : super(key: key);

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _participantNameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _selectedParticipants = [];

  @override
  void initState() {
    super.initState();
    // Add host as first participant
    _selectedParticipants.add({
      'userId': widget.hostId,
      'name': widget.hostName,
      'isHost': true,
    });
  }

  void _addParticipant(String name) {
    if (name.isEmpty) return;

    setState(() {
      _selectedParticipants.add({
        'userId': '', // Empty for now, will be assigned later
        'name': name,
        'isHost': false,
      });
      _participantNameController.clear();
    });
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create room document with selected participants
      final roomRef = await FirebaseFirestore.instance.collection('rooms').add({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'participants': _selectedParticipants,
      });

      // Only update the host's rooms array since other participants are pending
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.hostId)
          .update({
            'rooms': FieldValue.arrayUnion([roomRef.id]),
          });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create room: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create New Room',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                filled: true,
                fillColor: Colors.white,
              ),
              validator:
                  (value) =>
                      value?.isEmpty == true ? 'Room name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 3,
              validator:
                  (value) =>
                      value?.isEmpty == true ? 'Description is required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _participantNameController,
                    decoration: const InputDecoration(
                      labelText: 'Add Participant',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      () => _addParticipant(_participantNameController.text),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Participants (${_selectedParticipants.length}):',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _selectedParticipants.length,
                      itemBuilder: (context, index) {
                        final participant = _selectedParticipants[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            participant['name'] as String,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing:
                              participant['isHost'] == true
                                  ? const Chip(label: Text('Host'))
                                  : IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedParticipants.removeAt(index);
                                      });
                                    },
                                  ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _createRoom,
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Create Room'),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
