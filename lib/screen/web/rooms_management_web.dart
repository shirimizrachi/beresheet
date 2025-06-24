import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/app_config.dart';
import '../../services/web/web_jwt_session_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RoomsManagementWeb extends StatefulWidget {
  const RoomsManagementWeb({Key? key}) : super(key: key);

  @override
  State<RoomsManagementWeb> createState() => _RoomsManagementWebState();
}

class _RoomsManagementWebState extends State<RoomsManagementWeb> {
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCreating = false;
  final TextEditingController _roomNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/rooms'),
        headers: await WebJwtSessionService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> roomsData = json.decode(response.body);
        setState(() {
          _rooms = roomsData.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.failedToLoadRooms(response.statusCode.toString());
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.errorLoadingRooms(e.toString());
        _isLoading = false;
      });
    }
  }

  Future<void> _createRoom() async {
    if (_roomNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterRoomName)),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/rooms'),
        headers: await WebJwtSessionService.getAuthHeaders(),
        body: json.encode({
          'room_name': _roomNameController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        _roomNameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.roomCreatedSuccessfully)),
        );
        await _loadRooms();
      } else {
        String errorMessage = AppLocalizations.of(context)!.failedToCreateRoom;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (e) {
          // Use default error message
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorCreatingRoom(e.toString()))),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  Future<void> _deleteRoom(String roomId, String roomName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmDeleteRoom),
        content: Text(AppLocalizations.of(context)!.areYouSureDeleteRoom(roomName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/rooms/$roomId'),
        headers: await WebJwtSessionService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.roomDeletedSuccessfully(roomName))),
        );
        await _loadRooms();
      } else {
        String errorMessage = AppLocalizations.of(context)!.failedToDeleteRoom;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (e) {
          // Use default error message
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorDeletingRoom(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.meeting_room, size: 32, color: Colors.blue),
                const SizedBox(width: 16),
                Text(
                  AppLocalizations.of(context)!.roomsManagement,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadRooms,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Create Room Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.createNewRoom,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _roomNameController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.roomName,
                              hintText: AppLocalizations.of(context)!.enterRoomName,
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _createRoom(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _isCreating ? null : _createRoom,
                          icon: _isCreating 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add),
                          label: Text(_isCreating ? AppLocalizations.of(context)!.creatingRoom : AppLocalizations.of(context)!.createRoom),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Rooms List
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.existingRoomsCount(_rooms.length),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildRoomsList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.errorTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRooms,
              child: Text(AppLocalizations.of(context)!.retryButton),
            ),
          ],
        ),
      );
    }

    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noRoomsFound,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.createFirstRoom),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.meeting_room, color: Colors.white),
            ),
            title: Text(
              room['room_name'] ?? AppLocalizations.of(context)!.unknownRoom,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(AppLocalizations.of(context)!.roomId(room['id'].toString())),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteRoom(
                room['id']?.toString() ?? '',
                room['room_name'] ?? AppLocalizations.of(context)!.unknownRoom,
              ),
              tooltip: AppLocalizations.of(context)!.deleteRoom,
            ),
          ),
        );
      },
    );
  }
}