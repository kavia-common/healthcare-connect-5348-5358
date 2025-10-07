# healthcare-connect-5348-5358

MongoDB (healthcare_database) preview notes:
- Ensure the container entrypoint executes: healthcare_database/startup.sh
- startup.sh:
  - Creates /var/lib/mongodb and /var/run/mongodb, cleans stale locks.
  - Starts mongod bound to 0.0.0.0:5001 with inline config.
  - Waits for readiness using mongosh ping, falls back to TCP if mongosh not present.
  - Creates admin/app users if mongosh is available.
  - Writes db_connection.txt and db_visualizer/mongodb.env aligned to port 5001.

Healthcheck:
- healthcare_database/healthcheck.sh:
  - Primary: mongosh ping.
  - Fallback: TCP connect (/dev/tcp/127.0.0.1/5001) and 'ss -lnt' port check.
  - Usage: ./healthcheck.sh 5001

Connection:
- db_connection.txt contains a ready-to-run mongosh command string.
- For visualizer, source: source healthcare_database/db_visualizer/mongodb.env
