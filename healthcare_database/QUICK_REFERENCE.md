# MongoDB Quick Reference Guide

## Quick Status Check

```bash
# Is MongoDB running?
ps aux | grep mongod | grep -v grep

# Is port 5001 listening?
ss -tlnp | grep 5001

# Can MongoDB respond?
mongosh --port 5001 --eval "db.adminCommand('ping')"

# Run full health check
bash healthcheck.sh 5001
```

## Common Operations

### Start MongoDB
```bash
cd healthcare-connect-5348-5358/healthcare_database
bash startup.sh
```

### Stop MongoDB
```bash
# Graceful shutdown
mongosh --port 5001 --eval "db.adminCommand('shutdown')"

# Force stop (if needed)
pkill -x mongod
```

### Restart MongoDB
```bash
pkill -x mongod
sleep 3
bash startup.sh
```

### Check Logs
```bash
# Last 50 lines
sudo tail -50 /var/lib/mongodb/mongod.log

# Follow logs in real-time
sudo tail -f /var/lib/mongodb/mongod.log

# Search for errors
sudo grep -i error /var/lib/mongodb/mongod.log
```

### Connect to Database
```bash
# Using connection file
$(cat db_connection.txt)

# Direct connection
mongosh mongodb://localhost:5001/myapp

# List databases
mongosh --port 5001 --eval "show dbs"

# List collections
mongosh --port 5001 --eval "use myapp; show collections"
```

## Troubleshooting Commands

### Port Already in Use
```bash
# Find what's using port 5001
lsof -i :5001

# Stop the process
pkill -x mongod
```

### Permission Issues
```bash
# Fix directory permissions
sudo chown -R $(whoami):$(whoami) /var/lib/mongodb /var/run/mongodb
sudo chmod 755 /var/lib/mongodb
```

### Clean Start (Reset Everything)
```bash
# Stop MongoDB
pkill -x mongod

# Remove data (WARNING: deletes all data!)
sudo rm -rf /var/lib/mongodb/*

# Restart
bash startup.sh
```

### Check MongoDB Version
```bash
mongod --version
mongosh --version
```

## Health Check Exit Codes

| Code | Meaning |
|------|---------|
| 0 | MongoDB is ready |
| 1 | MongoDB is not ready |

## Connection Strings

### Development (No Auth)
```
mongodb://localhost:5001/myapp
```

### Production (With Auth)
```
mongodb://appuser:dbuser123@localhost:5001/myapp?authSource=admin
```

## Key Files

| File | Purpose |
|------|---------|
| `startup.sh` | Starts MongoDB and visualizer |
| `healthcheck.sh` | Checks if MongoDB is ready |
| `mongod.conf` | MongoDB configuration |
| `db_connection.txt` | Ready-to-use connection command |
| `db_visualizer/mongodb.env` | Environment variables for apps |
| `/var/lib/mongodb/mongod.log` | MongoDB logs |

## Emergency Contacts

If MongoDB won't start after following troubleshooting steps:

1. Run the diagnostic test: `bash test_startup.sh`
2. Check logs: `sudo tail -100 /var/lib/mongodb/mongod.log`
3. Verify disk space: `df -h /var/lib/mongodb`
4. Check system resources: `free -h && top -bn1 | head -20`
