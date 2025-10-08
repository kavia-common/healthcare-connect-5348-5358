# DB Visualizer Startup Fix

## Issue Description
The db_visualizer component was failing to start due to a corrupted or incomplete express module installation. The error message was:
```
Error: Cannot find module './lib/express'
```

This occurred because the `node_modules/express/lib` directory was missing from the express package installation.

## Fix Applied

### 1. Updated startup.sh Script
The startup script (`healthcare_database/startup.sh`) has been enhanced with the following improvements:

#### Dependency Installation
- Automatically checks if `node_modules` exists and if express module is properly installed
- Detects missing `node_modules/express/lib` directory
- Runs `npm ci` (or `npm install` as fallback) to restore dependencies before starting the visualizer

#### Resilient Startup
- Uses error handling to ensure MongoDB continues running even if visualizer fails
- Provides clear warning messages when visualizer cannot start
- Exits gracefully without bringing down MongoDB

#### Node.js Availability Check
- Verifies Node.js and npm are available before attempting visualizer startup
- Skips visualizer if Node.js is not installed

### 2. How It Works

1. **MongoDB starts first** - Port 5001, no authentication for preview
2. **Visualizer dependency check** - Validates node_modules and express/lib
3. **Automatic reinstall** - If corrupted/missing, runs `npm ci` or `npm install`
4. **Graceful degradation** - If visualizer fails, MongoDB stays running with clear messages

### 3. Testing the Fix

To verify the fix works:

```bash
# From healthcare_database directory
./startup.sh
```

Expected output:
```
[startup] Starting MongoDB setup (port 5001)...
[startup] Starting MongoDB server on 0.0.0.0:5001...
[startup] MongoDB is ready on port 5001!
[startup] MongoDB setup complete!
[startup] Starting db_visualizer...
[startup] Installing db_visualizer dependencies...
[startup] Dependencies installed successfully with npm ci
[startup] db_visualizer started successfully
```

### 4. Manual Fix (if needed)

If you need to manually fix corrupted node_modules:

```bash
cd healthcare_database/db_visualizer
rm -rf node_modules package-lock.json
npm install
```

## Connection Information

Even if the visualizer fails to start, MongoDB is accessible:

**Connection String:**
```
mongodb://localhost:5001/myapp
```

**Using mongosh:**
```bash
mongosh mongodb://localhost:5001/myapp
```

**Environment Variables:**
The connection details are written to:
- `db_connection.txt` - Ready-to-run mongosh command
- `db_visualizer/mongodb.env` - Environment variables for applications

## Acceptance Criteria Met

✅ MongoDB remains running on port 5001
✅ db_visualizer starts successfully after dependency installation
✅ No unhandled 'MODULE_NOT_FOUND' errors on startup
✅ Startup script degrades gracefully if visualizer can't start
✅ Documented fix in this README

## Node Version Compatibility

This fix is compatible with Node.js 18+ (the expected environment version). The visualizer uses:
- express: ^4.18.2
- mongodb driver: ^6.2.0
- Other database adapters (pg, mysql2, sqlite3)

## Future Maintenance

To prevent similar issues:
1. Always use `npm ci` in containerized environments for reproducible installs
2. Include `.npmrc` with `package-lock=true` to enforce lock file usage
3. Consider pre-building node_modules in container image
4. Add healthcheck for visualizer service (optional)
