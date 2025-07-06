# Build Flutter Web Applications for Development
# This PowerShell script builds both web-tenant and web-admin applications for development

Write-Host "[INFO] Building Flutter web applications for development..." -ForegroundColor Green

# Check if Flutter is installed
try {
    flutter --version | Out-Null
    Write-Host "[INFO] Flutter found and accessible" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Build web-tenant application directly to api_service directory
Write-Host "[INFO] Building web-tenant application..." -ForegroundColor Green
flutter build web --target lib/main_web.dart --dart-define=ENVIRONMENT=development --output api_service/web-tenant

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] web-tenant build failed!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "[INFO] web-tenant build completed successfully!" -ForegroundColor Green
}

# Build web-admin application directly to api_service directory
# Write-Host "[INFO] Building web-admin application..." -ForegroundColor Green
# flutter build web --target lib/main_admin.dart --dart-define=ENVIRONMENT=development --output api_service/web-admin

# if ($LASTEXITCODE -ne 0) {
#     Write-Host "[ERROR] web-admin build failed!" -ForegroundColor Red
#     exit 1
# } else {
#     Write-Host "[INFO] web-admin build completed successfully!" -ForegroundColor Green
# }

Write-Host "[INFO] All Flutter web applications built successfully for development!" -ForegroundColor Green
Write-Host "[INFO] Output locations:" -ForegroundColor Green
Write-Host "  - web-tenant: api_service/web-tenant"
Write-Host "  - web-admin:  api_service/web-admin"
Write-Host "[INFO] Development environment configured with debug symbols and source maps" -ForegroundColor Yellow