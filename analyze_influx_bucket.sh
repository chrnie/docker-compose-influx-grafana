#!/bin/bash
# Usage: ./analyze_influx.sh <BUCKET> <DEBUG>

BUCKET=$1
DEBUG=$2

if [ -z "$BUCKET" ]; then
  echo "Usage: ./analyze_influx.sh <BUCKET> <DEBUG>"
  exit 3
fi

MEASUREMENTS=$(influx query \
  'import "influxdata/influxdb/schema"
  from(bucket:"'"$BUCKET"'")
    |> range(start: -30d)
    |> keep(columns: ["_measurement"])
    |> group()
    |> distinct(column: "_measurement")' \
    |tail -n +5|sed 's/\s*//g' )


if [ -n "$DEBUG" ]; then
  echo "=== Measurements in bucket $BUCKET ==="
  echo "$MEASUREMENTS"
fi

for m in $MEASUREMENTS; do
  if [ -n "$DEBUG" ]; then
    echo -e "\n--- Measurement: $m ---"
  fi
  # Field Count
  FIELD_COUNT=$(influx query \
  "import \"influxdata/influxdb/schema\"
  schema.measurementFieldKeys(bucket: \"$BUCKET\", measurement: \"$m\") |> count()" \
  |tail -n +5|sed 's/\s*//g' )
  if [ -n "$DEBUG" ]; then
    echo "FIELD COUNT: $FIELD_COUNT"
    influx query \
    "import \"influxdata/influxdb/schema\"
    schema.measurementFieldKeys(bucket: \"$BUCKET\", measurement: \"$m\")"
  fi

  # Measurement cardinality
  M_CARD=$(influx query \
  "import \"influxdata/influxdb\" \
  influxdb.cardinality(bucket: \"$BUCKET\", start: -12h, predicate: (r) => r._measurement == \"$m\")" \
  |tail -n +5|sed 's/\s*//g' )
  if [ -n "$DEBUG" ]; then
    echo "MEASUREM CARDINALITY: $M_CARD"
  fi
  

  # Tag Count
  TAG_COUNT=$(influx query \
  "import \"influxdata/influxdb/schema\"
  schema.measurementTagKeys(bucket: \"$BUCKET\", measurement: \"$m\") " \
  |tail -n +5|sed 's/\s*//g'|grep -vP "_start|_stop|_field|_measurement"|wc -l)
  if [ -n "$DEBUG" ]; then
    echo "TAG COUNT: $TAG_COUNT"
    influx query \
    "import \"influxdata/influxdb/schema\"
    schema.measurementTagKeys(bucket: \"$BUCKET\", measurement: \"$m\")" \
    |tail -n +5|sed 's/\s*//g'|grep -vP "_start|_stop|_field|_measurement"
  fi

  # Alle Tag-Keys abrufen
  TAG_KEYS=$(influx query \
  "import \"influxdata/influxdb/schema\"
  schema.measurementTagKeys(bucket: \"$BUCKET\", measurement: \"$m\")" \
  |tail -n +9|sed 's/\s*//g' )
  if [ -n "$DEBUG" ]; then
    echo "TAG KEYS: $TAG_KEYS"
  fi

  TAGS_JSON=""
  if [ -z "$TAG_KEYS" ]; then
    if [ -n "$DEBUG" ]; then
      echo "No Tags"
    fi
    TAGS_JSON="[]"
  else
    for t in $TAG_KEYS; do

      if [ -n "$DEBUG" ]; then
        echo -n "TAG Value Count: $t - "
      fi

      # Value count per tag
      VALUE_COUNT=$(influx query \
      "import \"influxdata/influxdb/schema\"
      schema.measurementTagValues(bucket: \"$BUCKET\", measurement: \"$m\", tag: \"$t\") |> count()" \
      |tail -n +5|sed 's/\s*//g' )
      if [ -n "$DEBUG" ]; then
        echo "$VALUE_COUNT"
      fi
      TAGS_JSON+="{\"tag\":\"$t\",\"value_count\":$VALUE_COUNT},"

    done
    # remove last comma
    TAGS_JSON="[${TAGS_JSON}]"
  fi
  JSON_OUTPUT+="{\"measurement\":\"$m\",\"field_count\":$FIELD_COUNT,\"Cardinality\":$M_CARD,\"tag_count\":$TAG_COUNT,\"tags\":$TAGS_JSON},"
done
JSON_OUTPUT="[${JSON_OUTPUT}]"


echo "$JSON_OUTPUT" | sed 's/,]/]/g' 
