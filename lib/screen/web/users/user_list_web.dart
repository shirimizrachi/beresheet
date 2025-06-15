import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:beresheet_app/services/web_auth_service.dart';
import 'package:beresheet_app/model/user.dart';
import 'edit_user_web.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';

class UserListWeb extends StatefulWidget {
  const UserListWeb({Key? key}) : super(key: key);

  @override
  State<UserListWeb> createState() => _UserListWebState();
}

class _UserListWebState extends State<UserListWeb> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  void _checkPermissions() {
    final userRole = WebAuthService.userRole ?? '';
    if (userRole != 'manager') {
      setState(() {
        _errorMessage = AppLocalizations.of(context)?.accessDeniedManagerRoleUserList ??
                       'Access denied: Manager role required to view user list';
        _isLoading = false;
      });
      return;
    }
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final headers = WebAuthService.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/users'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> usersJson = json.decode(response.body);
        setState(() {
          _users = usersJson.map((json) => UserModel.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = AppLocalizations.of(context)?.failedToLoadUsers(response.statusCode.toString()) ??
                         'Failed to load users: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)?.errorLoadingUsers(e.toString()) ??
                       'Error loading users: $e';
        _isLoading = false;
      });
    }
  }

  void _editUser(UserModel user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditUserWeb(user: user),
      ),
    ).then((_) {
      // Refresh the list when returning from edit web
      _loadUsers();
    });
  }

  String _formatRole(String role) {
    return DisplayNameUtils.getUserRoleDisplayName(role, context);
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return AppLocalizations.of(context)?.notAvailable ?? 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.usersManagementTitle ?? 'User Management',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUsers,
            tooltip: AppLocalizations.of(context)?.refreshTooltip ?? 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadUsers,
              child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)?.noUsersFound ?? 'No users found',
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)?.totalUsers(_users.length) ?? 'All Users (${_users.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            _buildDataTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: [
          DataColumn(label: Text(AppLocalizations.of(context)?.fullName ?? 'Full Name', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(AppLocalizations.of(context)?.phoneColumn ?? 'Phone', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(AppLocalizations.of(context)?.role ?? 'Role', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(AppLocalizations.of(context)?.apartmentNumber ?? 'Apartment', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(AppLocalizations.of(context)?.birthday ?? 'Birthday', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(AppLocalizations.of(context)?.gender ?? 'Gender', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(AppLocalizations.of(context)?.actionsColumn ?? 'Actions', style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _users.map((user) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  user.fullName.isNotEmpty ? user.fullName : (AppLocalizations.of(context)?.notAvailable ?? 'N/A'),
                  style: TextStyle(
                    fontWeight: user.fullName.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                    color: user.fullName.isNotEmpty ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              DataCell(Text(user.phoneNumber)),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatRole(user.role),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              DataCell(
                Text(
                  user.apartmentNumber.isNotEmpty ? user.apartmentNumber : (AppLocalizations.of(context)?.notAvailable ?? 'N/A'),
                  style: TextStyle(
                    color: user.apartmentNumber.isNotEmpty ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              DataCell(Text(_formatDate(user.birthday.toIso8601String()))),
              DataCell(
                Text(
                  user.gender.isNotEmpty ? user.gender : (AppLocalizations.of(context)?.notAvailable ?? 'N/A'),
                  style: TextStyle(
                    color: user.gender.isNotEmpty ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              DataCell(
                ElevatedButton.icon(
                  onPressed: () => _editUser(user),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(AppLocalizations.of(context)?.editUser ?? 'Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'manager':
        return Colors.purple;
      case 'staff':
        return Colors.blue;
      case 'instructor':
        return Colors.green;
      case 'resident':
        return Colors.orange;
      case 'caregiver':
        return Colors.teal;
      case 'service':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}