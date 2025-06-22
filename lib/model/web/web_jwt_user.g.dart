// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_jwt_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebJwtUser _$WebJwtUserFromJson(Map<String, dynamic> json) => WebJwtUser(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as String,
      homeId: (json['homeId'] as num).toInt(),
      photo: json['photo'] as String?,
      apartmentNumber: json['apartmentNumber'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$WebJwtUserToJson(WebJwtUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'phoneNumber': instance.phoneNumber,
      'fullName': instance.fullName,
      'role': instance.role,
      'homeId': instance.homeId,
      'photo': instance.photo,
      'apartmentNumber': instance.apartmentNumber,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

WebJwtSession _$WebJwtSessionFromJson(Map<String, dynamic> json) =>
    WebJwtSession(
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
      user: WebJwtUser.fromJson(json['user'] as Map<String, dynamic>),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      refreshExpiresAt: DateTime.parse(json['refreshExpiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$WebJwtSessionToJson(WebJwtSession instance) =>
    <String, dynamic>{
      'token': instance.token,
      'refreshToken': instance.refreshToken,
      'user': instance.user,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'refreshExpiresAt': instance.refreshExpiresAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

WebJwtCredentials _$WebJwtCredentialsFromJson(Map<String, dynamic> json) =>
    WebJwtCredentials(
      phoneNumber: json['phoneNumber'] as String,
      password: json['password'] as String,
      homeId: (json['homeId'] as num).toInt(),
    );

Map<String, dynamic> _$WebJwtCredentialsToJson(WebJwtCredentials instance) =>
    <String, dynamic>{
      'phoneNumber': instance.phoneNumber,
      'password': instance.password,
      'homeId': instance.homeId,
    };

WebJwtLoginResult _$WebJwtLoginResultFromJson(Map<String, dynamic> json) =>
    WebJwtLoginResult(
      success: json['success'] as bool,
      message: json['message'] as String,
      session: json['session'] == null
          ? null
          : WebJwtSession.fromJson(json['session'] as Map<String, dynamic>),
      error: json['error'] as String?,
    );

Map<String, dynamic> _$WebJwtLoginResultToJson(WebJwtLoginResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'session': instance.session,
      'error': instance.error,
    };
