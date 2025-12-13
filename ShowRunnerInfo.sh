#!/bin/bash

# This script prints system information about the runner, including CPU, memory, and disk usage.
# It is useful for debugging and auditing the environment where the workflow is running.

set -e

# Display CPU information (architecture, model, cores, etc.)
cat /proc/cpuinfo

echo

# Display memory usage in a human-readable format
free --human

echo

# Display disk space usage in a human-readable format
df --human-readable
