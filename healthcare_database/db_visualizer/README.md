# db_visualizer (placeholder)

This directory is intentionally added as a placeholder to satisfy startup scripts that `cd` into:
`healthcare_database/db_visualizer`

Some scripts expect this path to exist for DB visualization/configuration purposes. Without it, startup may fail with:
`cd: .../db_visualizer: No such file or directory`

You can safely ignore this directory if you are not using any visualization tooling. If desired, you may store DB visualization related assets/config here, for example:
- MongoDB Compass connection profiles
- Mongo Express configuration files
- Utility scripts for visualizing collections or indexes

No code is executed from this directory by default.
