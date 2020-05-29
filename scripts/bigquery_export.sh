#!/bin/bash

# shellcheck source=strides_env.sh
. ./strides_env.sh

export GOOGLE_APPLICATION_CREDENTIALS=/home/vartanianmh/sandbox-blast-847af7ab431a.json
gcloud config set account 1008590670571-compute@developer.gserviceaccount.com
export CLOUDSDK_CORE_PROJECT="ncbi-sandbox-blast"

bq rm -f strides_analytics.detail_export

bq show --schema strides_analytics.s3_parsed

# shellcheck disable=SC2016
bq query \
    --destination_table strides_analytics.detail_export \
    --use_legacy_sql=false \
    --batch=true \
    --max_rows=10 \
   'SELECT
  ip as ip,
  parse_datetime("%d.%m.%Y:%H:%M:%S 0", time) as start_ts, -- 27.5.2020:22:35:16
  split(request, " ")[offset (1)] as uri,
  res_code as status,
  res_len as bytecount,
  referer as referer,
  agent as agent, -- TODO: -head
  datetime_add(parse_datetime("%d.%m.%Y:%H:%M:%S 0", time), interval total_time millisecond) as end_ts,
  host_header as host,
  split(request," ")[offset (0)] as cmd,
  bucket as bucket,
  source as source
  FROM
  `ncbi-sandbox-blast.strides_analytics.s3_parsed`
  '


bq extract \
    --destination_format NEWLINE_DELIMITED_JSON \
    --compression GZIP \
    'strides_analytics.detail_export' \
    "gs://strides_analytics/detail/detail.$DATE.*.json.gz"

gsutil ls "gs://strides_analytics/detail/detail.$DATE.*"

mkdir -p "$PANFS/detail"
cd "$PANFS/detail" || exit
rm "$PANFS"/detail/detail."$DATE".* || true

gsutil -m cp -r "gs://strides_analytics/detail/detail.$DATE.*" "$PANFS/detail/"

date
