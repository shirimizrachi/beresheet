import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../model/admin/tenant.dart';
import '../../model/admin/tenant_table.dart';
import '../../config/admin_config.dart';
import 'admin_auth_service.dart';
import 'admin_session_service.dart';

/// Admin API service for interacting with admin endpoints
/// Handles all communication with the admin.py backend
class AdminApiService {
  
  /// Get all tenants
  static Future<List<Tenant>> getTenants() async {
    try {
      print('Fetching all tenants');
      
      final headers = await AdminAuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.adminTenantsEndpoint}'),
        headers: headers,
      ).timeout(AdminConfig.apiTimeout);
      
      print('Get tenants response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> tenantsJson = jsonDecode(response.body) as List<dynamic>;
        final tenants = tenantsJson
            .map((json) => Tenant.fromJson(json as Map<String, dynamic>))
            .toList();
        
        print('Successfully fetched ${tenants.length} tenants');
        return tenants;
      } else if (response.statusCode == 401) {
        await AdminAuthService.handleAuthError('Unauthorized');
        throw Exception('Authentication required');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Failed to fetch tenants';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error fetching tenants: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else if (AdminSessionService.isAuthenticationError(e)) {
        await AdminAuthService.handleAuthError(e);
        rethrow;
      } else {
        throw Exception('Failed to fetch tenants: ${e.toString()}');
      }
    }
  }
  
  /// Get tenant by name
  static Future<Tenant?> getTenantByName(String tenantName) async {
    try {
      print('Fetching tenant: $tenantName');
      
      final headers = await AdminAuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.getTenantByNameEndpoint(tenantName)}'),
        headers: headers,
      ).timeout(AdminConfig.apiTimeout);
      
      print('Get tenant response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final tenantJson = jsonDecode(response.body) as Map<String, dynamic>;
        final tenant = Tenant.fromJson(tenantJson);
        print('Successfully fetched tenant: ${tenant.name}');
        return tenant;
      } else if (response.statusCode == 404) {
        print('Tenant not found: $tenantName');
        return null;
      } else if (response.statusCode == 401) {
        await AdminAuthService.handleAuthError('Unauthorized');
        throw Exception('Authentication required');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Failed to fetch tenant';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error fetching tenant $tenantName: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else if (AdminSessionService.isAuthenticationError(e)) {
        await AdminAuthService.handleAuthError(e);
        rethrow;
      } else {
        throw Exception('Failed to fetch tenant: ${e.toString()}');
      }
    }
  }
  
  /// Create new tenant
  static Future<Tenant> createTenant(TenantCreate tenantData) async {
    try {
      print('Creating tenant: ${tenantData.name}');
      
      final headers = await AdminAuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.adminTenantsEndpoint}'),
        headers: headers,
        body: jsonEncode(tenantData.toJson()),
      ).timeout(AdminConfig.longOperationTimeout); // Longer timeout for tenant creation
      
      print('Create tenant response status: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final tenantJson = jsonDecode(response.body) as Map<String, dynamic>;
        final tenant = Tenant.fromJson(tenantJson);
        print('Successfully created tenant: ${tenant.name}');
        return tenant;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Invalid tenant data';
        throw Exception(errorMessage);
      } else if (response.statusCode == 401) {
        await AdminAuthService.handleAuthError('Unauthorized');
        throw Exception('Authentication required');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Failed to create tenant';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error creating tenant ${tenantData.name}: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else if (AdminSessionService.isAuthenticationError(e)) {
        await AdminAuthService.handleAuthError(e);
        rethrow;
      } else {
        throw Exception('Failed to create tenant: ${e.toString()}');
      }
    }
  }
  
  /// Update tenant
  static Future<Tenant> updateTenant(int tenantId, TenantUpdate tenantUpdate) async {
    try {
      print('Updating tenant ID: $tenantId');
      
      final headers = await AdminAuthService.getAuthHeaders();
      final response = await http.put(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.getTenantEndpoint(tenantId)}'),
        headers: headers,
        body: jsonEncode(tenantUpdate.toJson()),
      ).timeout(AdminConfig.apiTimeout);
      
      print('Update tenant response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final tenantJson = jsonDecode(response.body) as Map<String, dynamic>;
        final tenant = Tenant.fromJson(tenantJson);
        print('Successfully updated tenant: ${tenant.name}');
        return tenant;
      } else if (response.statusCode == 404) {
        throw Exception('Tenant not found');
      } else if (response.statusCode == 401) {
        await AdminAuthService.handleAuthError('Unauthorized');
        throw Exception('Authentication required');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Failed to update tenant';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error updating tenant $tenantId: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else if (AdminSessionService.isAuthenticationError(e)) {
        await AdminAuthService.handleAuthError(e);
        rethrow;
      } else {
        throw Exception('Failed to update tenant: ${e.toString()}');
      }
    }
  }
  
  /// Delete tenant
  static Future<void> deleteTenant(int tenantId) async {
    try {
      print('Deleting tenant ID: $tenantId');
      
      final headers = await AdminAuthService.getAuthHeaders();
      final response = await http.delete(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.getTenantEndpoint(tenantId)}'),
        headers: headers,
      ).timeout(AdminConfig.apiTimeout);
      
      print('Delete tenant response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('Successfully deleted tenant ID: $tenantId');
      } else if (response.statusCode == 404) {
        throw Exception('Tenant not found');
      } else if (response.statusCode == 401) {
        await AdminAuthService.handleAuthError('Unauthorized');
        throw Exception('Authentication required');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Failed to delete tenant';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error deleting tenant $tenantId: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else if (AdminSessionService.isAuthenticationError(e)) {
        await AdminAuthService.handleAuthError(e);
        rethrow;
      } else {
        throw Exception('Failed to delete tenant: ${e.toString()}');
      }
    }
  }
  
  /// Get tenant tables
  static Future<TenantTablesResponse> getTenantTables(String tenantName) async {
    try {
      print('Fetching tables for tenant: $tenantName');
      
      final headers = await AdminAuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.getTenantTablesEndpoint(tenantName)}'),
        headers: headers,
      ).timeout(AdminConfig.apiTimeout);
      
      print('Get tenant tables response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
        final tablesResponse = TenantTablesResponse.fromJson(responseJson);
        print('Successfully fetched ${tablesResponse.tables.length} tables for tenant: $tenantName');
        return tablesResponse;
      } else if (response.statusCode == 404) {
        throw Exception('Tenant not found');
      } else if (response.statusCode == 401) {
        await AdminAuthService.handleAuthError('Unauthorized');
        throw Exception('Authentication required');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Failed to fetch tables';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error fetching tables for tenant $tenantName: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else if (AdminSessionService.isAuthenticationError(e)) {
        await AdminAuthService.handleAuthError(e);
        rethrow;
      } else {
        throw Exception('Failed to fetch tables: ${e.toString()}');
      }
    }
  }
  
  /// Recreate table
  static Future<TableOperationResponse> recreateTable(
    String tenantName,
    String tableName, {
    bool dropIfExists = true,
  }) async {
    try {
      print('Recreating table $tableName for tenant: $tenantName (drop: $dropIfExists)');
      
      final headers = await AdminAuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.getTableRecreateEndpoint(tenantName, tableName)}?drop_if_exists=$dropIfExists'),
        headers: headers,
      ).timeout(AdminConfig.longOperationTimeout);
      
      print('Recreate table response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
        final operationResponse = TableOperationResponse.fromJson(responseJson);
        print('Successfully recreated table: $tableName');
        return operationResponse;
      } else if (response.statusCode == 404) {
        throw Exception('Tenant or table not found');
      } else if (response.statusCode == 401) {
        await AdminAuthService.handleAuthError('Unauthorized');
        throw Exception('Authentication required');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Failed to recreate table';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error recreating table $tableName for tenant $tenantName: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else if (AdminSessionService.isAuthenticationError(e)) {
        await AdminAuthService.handleAuthError(e);
        rethrow;
      } else {
        throw Exception('Failed to recreate table: ${e.toString()}');
      }
    }
  }
  
  /// Load table data
  static Future<TableOperationResponse> loadTableData(String tenantName, String tableName) async {
    try {
      print('Loading demo data for table $tableName in tenant: $tenantName');
      
      final headers = await AdminAuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.getTableLoadDataEndpoint(tenantName, tableName)}'),
        headers: headers,
      ).timeout(AdminConfig.longOperationTimeout);
      
      print('Load table data response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
        final operationResponse = TableOperationResponse.fromJson(responseJson);
        print('Successfully loaded data for table: $tableName');
        return operationResponse;
      } else if (response.statusCode == 404) {
        throw Exception('Tenant or table not found');
      } else if (response.statusCode == 401) {
        await AdminAuthService.handleAuthError('Unauthorized');
        throw Exception('Authentication required');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Failed to load table data';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error loading data for table $tableName in tenant $tenantName: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else if (AdminSessionService.isAuthenticationError(e)) {
        await AdminAuthService.handleAuthError(e);
        rethrow;
      } else {
        throw Exception('Failed to load table data: ${e.toString()}');
      }
    }
  }
  
  /// Health check
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      print('Performing admin health check');
      
      final headers = await AdminAuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.adminHealthEndpoint}'),
        headers: headers,
      ).timeout(AdminConfig.apiTimeout);
      
      print('Health check response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final healthData = jsonDecode(response.body) as Map<String, dynamic>;
        print('Health check successful: ${healthData['status']}');
        return healthData;
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Health check failed';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error during health check: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else {
        throw Exception('Health check failed: ${e.toString()}');
      }
    }
  }
  
  /// Create schema and user
  static Future<Map<String, dynamic>> createSchema(String schemaName) async {
    try {
      print('Creating schema: $schemaName');
      
      final headers = await AdminAuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.getCreateSchemaEndpoint(schemaName)}'),
        headers: headers,
      ).timeout(AdminConfig.longOperationTimeout);
      
      print('Create schema response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        print('Successfully created schema: $schemaName');
        return responseData;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Invalid schema name';
        throw Exception(errorMessage);
      } else if (response.statusCode == 401) {
        await AdminAuthService.handleAuthError('Unauthorized');
        throw Exception('Authentication required');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Failed to create schema';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error creating schema $schemaName: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else if (AdminSessionService.isAuthenticationError(e)) {
        await AdminAuthService.handleAuthError(e);
        rethrow;
      } else {
        throw Exception('Failed to create schema: ${e.toString()}');
      }
    }
  }
}