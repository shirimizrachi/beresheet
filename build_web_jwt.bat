@echo off
echo Building Flutter Web with JWT Authentication...

echo.
echo Cleaning previous builds...
flutter clean

echo.
echo Getting dependencies...
flutter pub get

echo.
echo Generating JSON serialization code for JWT models...
flutter packages pub run build_runner build --delete-conflicting-outputs

echo.
echo Building web application...
flutter build web --web-renderer html --target lib/main_web.dart --output build/web-tenant

echo.
echo Web build complete! 
echo The application is now ready to serve with JWT authentication.
echo.
pause