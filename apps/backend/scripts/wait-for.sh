#!/bin/sh
# usage: ./wait-for.sh host port [timeout]
host="$1"
port="$2"
timeout=${3:-60}

count=0
while ! nc -z "$host" "$port"; do
  count=$((count+1))
  if [ "$count" -ge "$timeout" ]; then
    echo "Timeout waiting for $host:$port"
    exit 1
  fi
  echo "Waiting for $host:$port... ($count)"
  sleep 1
done

echo "$host:$port is available"
exit 0
