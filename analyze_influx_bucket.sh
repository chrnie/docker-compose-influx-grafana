#!/bin/bash
# Usage: ./analyze_influx.sh <BUCKET> <DEBUG>

BUCKET=$1
DEBUG=$2

if [ -z "$BUCKET" ]; then
  echo "Usage: ./analyze_influx.sh <BUCKET> <DEBUG>"
  exit 3
fi

if ! influx bucket list -n $BUCKET &>/dev/null; then
  echo "Make sure influx cli is functional and $BUCKET exist"
  exit 4
fi

# Query Measurements
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

# Query Fields, Tags, Cardinality per Measurement
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
  # Write rate per field (Points/h, last 24h)
  FIELD_KEYS=$(influx query \
  "import \"influxdata/influxdb/schema\"
  schema.measurementFieldKeys(bucket: \"$BUCKET\", measurement: \"$m\")" \
  |tail -n +5|sed 's/\s*//g')

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

  # Query all tag-keys
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

  FIELDS_JSON=""
  if [ -z "$FIELD_KEYS" ]; then
    if [ -n "$DEBUG" ]; then
      echo "No Tags"
    fi
    FIELDS_JSON="[]"
  else
    for f in $FIELD_KEYS; do

      # Point count per field
      POINT_COUNT=$(influx query \
        "from(bucket: \"$BUCKET\")
          |> range(start: -24h)
          |> filter(fn: (r) => r._measurement == \"$m\" and r._field == \"$f\")
          |> count() \
          |> keep(columns: [\"_value\"]) \
          |> sum(column: \"_value\")" \
        |tail -n +5|sed 's/\s*//g')
      if [[ \"$POINT_COUNT\" =~ ^[0-9]+$ ]]; then
        WRITE_RATE=$(echo "\"scale=2; $POINT_COUNT/24\"" | bc)
      else
        WRITE_RATE=0
      fi
      if [ -n "$DEBUG" ]; then
        echo "$POINT_COUNT"
      fi
      FIELDS_JSON+="{\"field\":\"$f\",\"point_count\":$POINT_COUNT,\"write_rate\":$WRITE_RATE},"

    done
    # remove last comma
    FIELDS_JSON="[${FIELDS_JSON}]"
  fi

  JSON_OUTPUT+="{\"measurement\":\"$m\",\"field_count\":$FIELD_COUNT,\"Cardinality\":$M_CARD,\"tag_count\":$TAG_COUNT,\"fields\":$FIELDS_JSON},"
done
JSON_OUTPUT="[${JSON_OUTPUT}]"


echo "$JSON_OUTPUT" | sed 's/,]/]/g' 
