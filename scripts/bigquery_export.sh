#!/usr/bin/bash

# shellcheck source=strides_env.sh
. ./strides_env.sh

export CLOUDSDK_CORE_PROJECT="ncbi-logmon"
gcloud config set account 253716305623-compute@developer.gserviceaccount.com

skipload=false
if [ "$#" -eq 1 ]; then
    if [ "$1" = "skipload" ]; then
        skipload=true
    fi
fi

if [ "$skipload" = false ]; then
gsutil du -s -h gs://logmon_logs/gs_public
gsutil du -s -h gs://logmon_logs/s3_public
gsutil du -s -h gs://logmon_logs_parsed_us/logs_gs_public/
gsutil du -s -h gs://logmon_logs_parsed_us/logs_s3_public/

# TODO: Partition/cluster large tables for incremental inserts and retrievals
# TODO: Materialized views that automatically refresh

echo " #### gs_parsed"
cat << EOF > gs_schema.json
    { "schema": { "fields": [
    { "name" : "accepted", "type": "BOOLEAN" },
    { "name" : "accession", "type": "STRING" },
    { "name" : "agent", "type": "STRING" },
    { "name" : "bucket", "type": "STRING" },
    { "name" : "extension", "type": "STRING" },
    { "name" : "filename", "type": "STRING" },
    { "name" : "host", "type": "STRING" },
    { "name" : "ip", "type": "STRING" },
    { "name" : "ip_region", "type": "STRING" },
    { "name" : "ip_type", "type": "INTEGER" },
    { "name" : "method", "type": "STRING" },
    { "name" : "operation", "type": "STRING" },
    { "name" : "path", "type": "STRING" },
    { "name" : "referer", "type": "STRING" },
    { "name" : "request_bytes", "type": "INTEGER" },
    { "name" : "request_id", "type": "STRING" },
    { "name" : "result_bytes", "type": "INTEGER" },
    { "name" : "source", "type": "STRING" },
    { "name" : "status", "type": "INTEGER" },
    { "name" : "time", "type": "INTEGER" },
    { "name" : "time_taken", "type": "INTEGER" },
    { "name" : "uri", "type": "STRING" },
    { "name" : "vers", "type": "STRING" } ,
    { "name" : "vdb_libc", "type": "STRING" },
    { "name" : "vdb_os", "type": "STRING" },
    { "name" : "vdb_phid_compute_env", "type": "STRING" },
    { "name" : "vdb_phid_guid", "type": "STRING" },
    { "name" : "vdb_phid_session_id", "type": "STRING" },
    { "name" : "vdb_release", "type": "STRING" },
    { "name" : "vdb_tool", "type": "STRING" }
    ]
  },
  "sourceFormat": "NEWLINE_DELIMITED_JSON",
  "sourceUris": [ "gs://logmon_logs_parsed_us/logs_gs_public/recognized.*" ]
}
EOF

    jq -S -c -e . < gs_schema.json > /dev/null
    jq -S -c .schema.fields < gs_schema.json > gs_schema_only.json

    #bq mk --external_table_definition=gs_schema_only.json strides_analytics.gs_parsed

    gsutil ls -lR "gs://logmon_logs_parsed_us/logs_gs_public/recognized.*"

    bq rm -f strides_analytics.gs_parsed
    bq load \
        --source_format=NEWLINE_DELIMITED_JSON \
        strides_analytics.gs_parsed \
        "gs://logmon_logs_parsed_us/logs_gs_public/recognized.*" \
        gs_schema_only.json
    bq show --schema strides_analytics.gs_parsed



echo " #### s3_parsed"
    cat << EOF > s3_schema.json
    { "schema": { "fields": [
        { "name" : "accepted", "type": "BOOLEAN" },
        { "name" : "accession", "type": "STRING" },
        { "name" : "agent", "type": "STRING" },
        { "name" : "auth_type", "type": "STRING" },
        { "name" : "bucket", "type": "STRING" },
        { "name" : "sig_ver", "type": "STRING" },
        { "name" : "cipher_suite", "type": "STRING" },
        { "name" : "error", "type": "STRING" },
        { "name" : "extension", "type": "STRING" },
        { "name" : "filename", "type": "STRING" },
        { "name" : "host_header", "type": "STRING" },
        { "name" : "host_id", "type": "STRING" },
        { "name" : "ip", "type": "STRING" },
        { "name" : "key", "type": "STRING" },
        { "name" : "method", "type": "STRING" },
        { "name" : "obj_size", "type": "STRING" },
        { "name" : "operation", "type": "STRING" },
        { "name" : "owner", "type": "STRING" },
        { "name" : "path", "type": "STRING" },
        { "name" : "referer", "type": "STRING" },
        { "name" : "request_id", "type": "STRING" },
        { "name" : "requester", "type": "STRING" },
        { "name" : "res_code", "type": "STRING" },
        { "name" : "res_len", "type": "STRING" },
        { "name" : "source", "type": "STRING" },
        { "name" : "time", "type": "STRING" },
        { "name" : "tls_version", "type": "STRING" },
        { "name" : "total_time", "type": "STRING" },
        { "name" : "turnaround_time", "type": "STRING" },
        { "name" : "vers", "type": "STRING" },
        { "name" : "version_id", "type": "STRING" },
        { "name" : "vdb_libc", "type": "STRING" },
        { "name" : "vdb_os", "type": "STRING" },
        { "name" : "vdb_phid_compute_env", "type": "STRING" },
        { "name" : "vdb_phid_guid", "type": "STRING" },
        { "name" : "vdb_phid_session_id", "type": "STRING" },
        { "name" : "vdb_release", "type": "STRING" },
        { "name" : "vdb_tool", "type": "STRING" }
        ]
    },
    "sourceFormat": "NEWLINE_DELIMITED_JSON",
    "sourceUris": [ "gs://logmon_logs_parsed_us/logs_s3_public/recogn*" ]
    }
EOF
    jq -S -c -e . < s3_schema.json > /dev/null
    jq -S -c .schema.fields < s3_schema.json > s3_schema_only.json

    gsutil ls -lR "gs://logmon_logs_parsed_us/logs_s3_public/recognized.*"

    bq rm -f strides_analytics.s3_parsed
    bq load \
        --max_bad_records 500 \
        --source_format=NEWLINE_DELIMITED_JSON \
        strides_analytics.s3_parsed \
        "gs://logmon_logs_parsed_us/logs_s3_public/recognized.*" \
        s3_schema_only.json

    bq show --schema strides_analytics.s3_parsed


echo " #### op_parsed"
# TODO
    cat << EOF > op_schema.json
    { "schema": { "fields": [
        { "name" : "accepted", "type": "BOOLEAN" },
        { "name" : "accession", "type": "STRING" },
        { "name" : "agent", "type": "STRING" },
        { "name" : "extension", "type": "STRING" },
        { "name" : "filename", "type": "STRING" },
        { "name" : "forwarded", "type": "STRING" },
        { "name" : "ip", "type": "STRING" },
        { "name" : "method", "type": "STRING" },
        { "name" : "path", "type": "STRING" },
        { "name" : "port", "type": "INTEGER" },
        { "name" : "referer", "type": "STRING" },
        { "name" : "req_len", "type": "INTEGER" },
        { "name" : "req_time", "type": "STRING" },
        { "name" : "res_code", "type": "INTEGER" },
        { "name" : "res_len", "type": "INTEGER" },
        { "name" : "server", "type": "STRING" },
        { "name" : "source", "type": "STRING" },
        { "name" : "time", "type": "STRING" },
        { "name" : "user", "type": "STRING" },
        { "name" : "vers", "type": "STRING" },
        { "name" : "vdb_libc", "type": "STRING" },
        { "name" : "vdb_os", "type": "STRING" },
        { "name" : "vdb_phid_compute_env", "type": "STRING" },
        { "name" : "vdb_phid_guid", "type": "STRING" },
        { "name" : "vdb_phid_session_id", "type": "STRING" },
        { "name" : "vdb_release", "type": "STRING" },
        { "name" : "vdb_tool", "type": "STRING" }
        ]
    },
    "sourceFormat": "NEWLINE_DELIMITED_JSON",
    "sourceUris": [ "gs://logmon_logs_parsed_us/logs_op_public/recogn*" ]
    }
EOF

    jq -S -c -e . < op_schema.json > /dev/null
    jq -S -c .schema.fields < op_schema.json > op_schema_only.json

    gsutil ls -lR "gs://logmon_logs_parsed_us/logs_op_public/recognized.*"

    bq rm -f strides_analytics.op_parsed
    bq load \
        --max_bad_records 5000 \
        --source_format=NEWLINE_DELIMITED_JSON \
        strides_analytics.op_parsed \
        "gs://logmon_logs_parsed_us/logs_op_public/recognized.*" \
        op_schema_only.json

    bq show --schema strides_analytics.op_parsed




echo " #### Parsed results"
bq -q query \
    --use_legacy_sql=false \
    "select source, accepted, min(time) as min_time, max(time) as max_time, count(*) as parsed_count from (select source, accepted, cast(time as string) as time from strides_analytics.gs_parsed union all select source, accepted, cast(time as string) as time from strides_analytics.s3_parsed union all select source, accepted, time as time from strides_analytics.op_parsed) group by source, accepted order by source"

fi # skipload

echo " #### gs_fixed"
    QUERY=$(cat <<-ENDOFQUERY
    SELECT
    ip as remote_ip,
        parse_datetime('%s', cast ( cast (time/1000000 as int64) as string) ) as start_ts,
    datetime_add(
        parse_datetime('%s', cast ( cast (time/1000000 as int64) as string) ),
        interval time_taken microsecond) as end_ts,
    replace(agent, '-head', '') as user_agent,
    cast (status as string) as http_status,
    host as host,
    method as http_operation,
    path as request_uri,
    referer as referer,
    regexp_extract(path,r'[DES]R[RZ][0-9]{5,10}') as accession,
    result_bytes as bytes_sent,
    substr(regexp_extract(path,r'[0-9]\.[0-9]{1,2}'),3) as version,
    case
        WHEN regexp_contains(bucket, r'-run-') THEN bucket || ' (ETL + BQS)'
        WHEN regexp_contains(bucket, r'-zq-') THEN bucket || ' (ETL - BQS)'
        WHEN regexp_contains(bucket, r'-src-') THEN bucket || ' (Original)'
        WHEN regexp_contains(bucket, r'-ca-') THEN bucket || ' (Controlled Access)'
        WHEN ends_with(bucket, '-cov2') and
            regexp_contains(path, r'sra-src') THEN bucket || ' (Original)'
        WHEN ends_with(bucket, '-cov2') and
            regexp_contains(path, r'run') THEN bucket || ' (ETL + BQS)'
        WHEN regexp_contains(bucket, r'sra-pub-assembly-1') THEN bucket || ' (ETL - BQS)'
    ELSE bucket || ' (Unknown)'
    END as bucket,
    source as source,
    current_datetime() as fixed_time
    FROM \\\`ncbi-logmon.strides_analytics.gs_parsed\\\`
    WHERE accepted=true
ENDOFQUERY
)

    # TODO Hack, cause I can't understand bash backtick quoting
    QUERY="${QUERY//\\/}"
    bq rm --project_id ncbi-logmon -f strides_analytics.gs_fixed
    # shellcheck disable=SC2016
    bq query \
    --project_id ncbi-logmon \
    --destination_table strides_analytics.gs_fixed \
    --use_legacy_sql=false \
    --batch=true \
    --max_rows=5 \
    "$QUERY"

    bq show --schema strides_analytics.gs_fixed



    #parse_datetime('%d.%m.%Y:%H:%M:%S 0', time) as start_ts,
    #[17/May/2019:23:19:24 +0000]
echo " #### s3_fixed"
    # LOGMON-1: Remove multiple -heads from agent
    QUERY=$(cat <<-ENDOFQUERY
    SELECT
    ip as remote_ip,
    parse_datetime('[%d/%b/%Y:%H:%M:%S +0000]', time) as start_ts,
    datetime_add(parse_datetime('[%d/%b/%Y:%H:%M:%S +0000]', time),
        interval cast (
                case when total_time='' THEN '0' ELSE total_time END
        as int64) millisecond) as end_ts,
    regexp_extract(path,r'[DES]R[RZ][0-9]{5,10}') as accession,
    substr(regexp_extract(path,r'[0-9]\.[0-9]{1,2}'),3) as version,
    case
        WHEN regexp_contains(agent, r'-head') THEN 'HEAD'
        ELSE method
        END as http_operation,
    cast(res_code as string) as http_status,
    host_header as host,
    cast (case WHEN res_len='' THEN '0' ELSE res_len END as int64) as bytes_sent,
    path as request_uri,
    referer as referer,
    replace(agent, '-head', '') as user_agent,
    source as source,
    case
        WHEN regexp_contains(bucket, r'-run-') THEN bucket || ' (ETL + BQS)'
        WHEN regexp_contains(bucket, r'-zq-') THEN bucket || ' (ETL - BQS)'
        WHEN regexp_contains(bucket, r'-src-') THEN bucket || ' (Original)'
        WHEN regexp_contains(bucket, r'-ca-') THEN bucket || ' (Controlled Access)'
        WHEN ends_with(bucket, '-cov2') and
            regexp_contains(path, r'sra-src') THEN bucket || ' (Original)'
        WHEN ends_with(bucket, '-cov2') and
            regexp_contains(path, r'run') THEN bucket || ' (ETL + BQS)'
    ELSE bucket || ' (Unknown)'
    END as bucket,
    current_datetime() as fixed_time
    FROM \\\`ncbi-logmon.strides_analytics.s3_parsed\\\`
    WHERE accepted=true
ENDOFQUERY
    )

    QUERY="${QUERY//\\/}"
    bq rm --project_id ncbi-logmon -f strides_analytics.s3_fixed
    # shellcheck disable=SC2016
    bq query \
    --project_id ncbi-logmon \
    --destination_table strides_analytics.s3_fixed \
    --use_legacy_sql=false \
    --batch=true \
    --max_rows=5 \
    "$QUERY"

    bq show --schema strides_analytics.s3_fixed

echo " #### op_fixed"
    # LOGMON-1: Remove multiple -heads from agent
    QUERY=$(cat <<-ENDOFQUERY
    SELECT
    ip as remote_ip,
    safe.parse_datetime('[%d/%b/%Y:%H:%M:%S -0400]', time) as start_ts,
    datetime_add(
        safe.parse_datetime('[%d/%b/%Y:%H:%M:%S -0400]', time),
        interval
            cast(1000*cast (req_time as float64) as int64)
        millisecond
        ) as end_ts,
    accession,
    substr(regexp_extract(path,r'[0-9]\.[0-9]{1,2}'),3) as version,
    case
        WHEN regexp_contains(agent, r'-head') THEN 'HEAD'
        ELSE method
        END as http_operation,
    cast(res_code as string) as http_status,
    server as host,
    res_len as bytes_sent,
    path as request_uri,
    referer as referer,
    replace(agent, '-head', '') as user_agent,
    'OP' as source,
    current_datetime() as fixed_time
    FROM \\\`ncbi-logmon.strides_analytics.op_parsed\\\`
    WHERE accepted=true
ENDOFQUERY
    )

    QUERY="${QUERY//\\/}"
    bq rm --project_id ncbi-logmon -f strides_analytics.op_fixed
    # shellcheck disable=SC2016
    bq query \
    --project_id ncbi-logmon \
    --destination_table strides_analytics.op_fixed \
    --use_legacy_sql=false \
    --batch=true \
    --max_rows=5 \
    "$QUERY"

    bq show --schema strides_analytics.op_fixed



echo " ##### detail_export"
    QUERY=$(cat <<-ENDOFQUERY
SELECT
    accession as accession,
    bucket as bucket,
    bytes_sent as bytes_sent,
    current_datetime() as export_time,
    end_ts,
    fixed_time as fixed_time,
    host as host,
    http_status as http_status,
    remote_ip as remote_ip,
    http_operation as http_operation,
    request_uri as request_uri,
    referer as referer,
    source as source,
    start_ts,
    user_agent as user_agent,
    version as version
    FROM \\\`strides_analytics.gs_fixed\\\`
UNION ALL SELECT
    accession as accession,
    bucket as bucket,
    bytes_sent as bytes_sent,
    current_datetime() as export_time,
    end_ts,
    fixed_time as fixed_time,
    host as host,
    http_status as http_status,
    remote_ip as remote_ip,
    http_operation as http_operation,
    request_uri as request_uri,
    referer as referer,
    source as source,
    start_ts,
    user_agent as user_agent,
    version as version
    FROM \\\`strides_analytics.s3_fixed\\\`
UNION ALL SELECT
    accession as accession,
    host as bucket,
    bytes_sent as bytes_sent,
    current_datetime() as export_time,
    end_ts,
    fixed_time as fixed_time,
    host as host,
    http_status as http_status,
    remote_ip as remote_ip,
    http_operation as http_operation,
    request_uri as request_uri,
    referer as referer,
    source as source,
    start_ts,
    user_agent as user_agent,
    version as version
    FROM \\\`strides_analytics.op_fixed\\\`

ENDOFQUERY
    )

    QUERY="${QUERY//\\/}"

    bq rm --project_id ncbi-logmon -f strides_analytics.detail_export
    # shellcheck disable=SC2016
    bq query \
    --project_id ncbi-logmon \
    --destination_table strides_analytics.detail_export \
    --use_legacy_sql=false \
    --batch=true \
    --max_rows=5 \
    "$QUERY"

    bq show --schema strides_analytics.detail_export

echo " ###  summary_grouped"
    QUERY=$(cat <<-ENDOFQUERY
    SELECT
    accession,
    user_agent,
    remote_ip,
    host,
    bucket,
    source,
    count(*) as num_requests,
    min(start_ts) as start_ts,
    max(end_ts) as end_ts,
    string_agg(distinct http_operation order by http_operation) as http_operations,
    string_agg(distinct http_status order by http_status) as http_statuses,
    string_agg(distinct referer) as referers,
    sum(bytes_sent) as bytes_sent,
    current_datetime() as export_time
    FROM \\\`strides_analytics.detail_export\\\`
    WHERE start_ts > '2000-01-01'
    GROUP BY accession, user_agent, remote_ip, host, bucket, source, datetime_trunc(start_ts, day),
    case
        WHEN http_operation in ('GET', 'HEAD') THEN 0
        WHEN http_operation='POST' THEN 1
        WHEN http_operation='PUT' THEN 2
        WHEN http_operation='DELETE' THEN 3
        WHEN http_operation='PATCH' THEN 4
        WHEN http_operation='OPTIONS' THEN 5
        WHEN http_operation='TRACE' THEN 6
        WHEN http_operation='CONNECT' THEN 7
    ELSE 99
    END
    HAVING bytes_sent > 0
ENDOFQUERY
    )

    QUERY="${QUERY//\\/}"

    bq rm --project_id ncbi-logmon -f strides_analytics.summary_grouped
    # shellcheck disable=SC2016
    bq query \
    --destination_table strides_analytics.summary_grouped \
    --use_legacy_sql=false \
    --batch=true \
    --max_rows=5 \
    "$QUERY"

    bq show --schema strides_analytics.summary_grouped

# LOGMON-85: op_fixed is 4/21->, excluding 4/24, 6/25, 6/260
echo " ###  op_sess"
    QUERY=$(cat <<-ENDOFQUERY
    INSERT INTO strides_analytics.summary_grouped
    (accession, user_agent, remote_ip, host,
    bucket, source, num_requests, start_ts, end_ts,
    http_operations,
    http_statuses,
    referers, bytes_sent, export_time)
    SELECT
        acc, agent, ip, domain,
        domain, 'OP', cnt, cast (start as datetime), cast (\\\`end\\\` as datetime),
        replace(cmds,' ',','),
        replace(status,' ',','),
        '', bytecount, current_datetime()
    FROM \\\`ncbi-logmon.strides_analytics.op_sess\\\`
    WHERE regexp_contains(acc,r'[DES]R[RZ][0-9]{5,10}')
    AND start between '2019-03-01' and '2020-04-21'
    AND domain not like '%amazon%'
    AND domain not like '%gap%'

ENDOFQUERY
)
    QUERY="${QUERY//\\/}"

    bq query \
    --use_legacy_sql=false \
    --batch=true \
    "$QUERY"

echo " ###  fix op_sess"
    QUERY=$(cat <<-ENDOFQUERY
    update strides_analytics.summary_grouped
    set
    bucket=ifnull(bucket,'') || ' (ETL + BQS)',
    http_operations=replace(http_operations,' ',','),
    http_statuses=replace(http_statuses,' ',','),
    user_agent=replace(user_agent, '-head', '')
    where source='OP'

ENDOFQUERY
)
    QUERY="${QUERY//\\/}"

    bq query --use_legacy_sql=false --batch=true "$QUERY"

echo " ###  uniq_ips"
    QUERY=$(cat <<-ENDOFQUERY
    SELECT DISTINCT remote_ip as remote_ip,
        case when
            regexp_contains(
            remote_ip,
                r'^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
                )
            then
                net.ipv4_to_int64(net.safe_ip_from_string(remote_ip))
        else
            6
    end as ipint
    FROM \\\`ncbi-logmon.strides_analytics.summary_grouped\\\`
    WHERE length(remote_ip) < 100
ENDOFQUERY
)
    #WHERE remote_ip like '%.%'
    QUERY="${QUERY//\\/}"

    bq rm --project_id ncbi-logmon -f strides_analytics.uniq_ips
    # shellcheck disable=SC2016
    bq query \
    --destination_table strides_analytics.uniq_ips \
    --use_legacy_sql=false \
    --batch=true \
    --max_rows=5 \
    "$QUERY"


RUN="no"
if [ "$RUN" = "yes" ]; then
# Only needs to be running when a lot of new IP addresses appear
echo " ###  iplookup_new"
    QUERY=$(cat <<-ENDOFQUERY
    SELECT remote_ip, ipint, country_code, region_name, city_name
    FROM \\\`ncbi-logmon.strides_analytics.ip2location\\\`
    JOIN \\\`ncbi-logmon.strides_analytics.uniq_ips\\\`
    ON (ipint >= ip_from and ipint <= ip_to)
ENDOFQUERY
)
    QUERY="${QUERY//\\/}"

    bq rm --project_id ncbi-logmon -f strides_analytics.iplookup_new2
    # shellcheck disable=SC2016
    bq query \
    --destination_table strides_analytics.iplookup_new2 \
    --use_legacy_sql=false \
    --batch=true \
    --max_rows=5 \
    "$QUERY"
fi # RUN


echo " ### Find new IP addresses"
    QUERY=$(cat <<-ENDOFQUERY
insert into strides_analytics.rdns (ip)
select distinct remote_ip as ip from strides_analytics.summary_export where remote_ip not in (select distinct ip from strides_analytics.rdns
)
ENDOFQUERY
)
    QUERY="${QUERY//\\/}"
    bq query --use_legacy_sql=false --batch=true "$QUERY"

echo " ### Find internal PUT/POST IPs"
    QUERY=$(cat <<-ENDOFQUERY
    UPDATE strides_analytics.rdns
    SET DOMAIN="NCBI Cloud (put.nlm.nih.gov)"
    WHERE ip in (
    SELECT distinct  remote_ip
    FROM \\\`ncbi-logmon.strides_analytics.summary_export\\\`
    where http_operations like '%P%'
    and http_statuses like '%200%')
ENDOFQUERY
)
    QUERY="${QUERY//\\/}"
    bq query --use_legacy_sql=false --batch=true "$QUERY"

echo " ### Find internal IAMs IPs"
    QUERY=$(cat <<-ENDOFQUERY
    UPDATE strides_analytics.rdns
    SET DOMAIN="NCBI Cloud (request.nlm.nih.gov)"
    WHERE ip in (
    SELECT distinct ip FROM \\\`ncbi-logmon.strides_analytics.s3_parsed\\\`
        WHERE requester like '%arn:aws:iam::783971887864%'
        or requester like '%arn:aws:iam::018000097103%'
        or requester like '%arn:aws:iam::867126678632%'
        or requester like '%arn:aws:iam::651740271041%' )
ENDOFQUERY
)
    QUERY="${QUERY//\\/}"
    bq query --use_legacy_sql=false --batch=true "$QUERY"

echo " ### Update RDNS"
    QUERY=$(cat <<-ENDOFQUERY
    UPDATE strides_analytics.rdns
    SET DOMAIN="Unknown"
    WHERE domain is null
ENDOFQUERY
)
    QUERY="${QUERY//\\/}"
    bq query --use_legacy_sql=false --batch=true "$QUERY"

    QUERY=$(cat <<-ENDOFQUERY
    UPDATE strides_analytics.rdns
    SET DOMAIN="IPv6"
    WHERE ip like '%:%'
    and domain='Unknown'
ENDOFQUERY
)
    QUERY="${QUERY//\\/}"
    bq query --use_legacy_sql=false --batch=true "$QUERY"

    QUERY=$(cat <<-ENDOFQUERY
    UPDATE strides_analytics.rdns
    SET DOMAIN="IPv6 IANA Unicast (ncbi.nlm.nih.gov)"
    WHERE ip like 'fda3%'
ENDOFQUERY
)
    QUERY="${QUERY//\\/}"
    bq query --use_legacy_sql=false --batch=true "$QUERY"

echo " ###  summary_export"
    QUERY=$(cat <<-ENDOFQUERY
    SELECT
    accession,
    user_agent,
    grouped.remote_ip,
    host,
    bucket,
    grouped.source,
    num_requests,
    start_ts,
    end_ts,
    http_operations,
    http_statuses,
    referers,
    bytes_sent,
    current_datetime() as export_time,
    case
        WHEN rdns.domain is null or rdns.domain='' or rdns.domain='Unknown' or rdns.domain='unknown'
            THEN 'Unknown (' || country_code || ')'
        ELSE rdns.domain
    END as domain,
    ifnull(region_name,'Unknown') as region_name,
    ifnull(country_code,'Unknown') as country_code,
    ifnull(city_name,'Unknown') as city_name,
    ifnull(organism, 'Unknown') as ScientificName,
    ifnull(consent,'Unknown') as consent,
    cast (mbytes as int64) as accession_size_mb
    FROM \\\`strides_analytics.summary_grouped\\\` grouped
    LEFT JOIN \\\`strides_analytics.rdns\\\` rdns
        ON grouped.remote_ip=rdns.ip
    LEFT JOIN \\\`strides_analytics.iplookup_new2\\\` iplookup
        ON grouped.remote_ip=iplookup.remote_ip
    LEFT JOIN \\\`nih-sra-datastore.sra.metadata\\\` metadata
        ON accession=metadata.acc
    WHERE
        accession IS NOT NULL AND accession != ""
ENDOFQUERY
    )

#    LEFT JOIN \\\`strides_analytics.public_fix\\\`
    QUERY="${QUERY//\\/}"

    bq \
        cp -f strides_analytics.summary_export "strides_analytics.summary_export_$YESTERDAY"
    bq rm --project_id ncbi-logmon -f strides_analytics.summary_export

    # shellcheck disable=SC2016
    bq query \
    --destination_table strides_analytics.summary_export \
    --use_legacy_sql=false \
    --batch=true \
    --max_rows=5 \
    "$QUERY"
    bq show --schema strides_analytics.summary_export

    OLD=$(date -d "-5 days" "+%Y%m%d")
    bq rm --project_id ncbi-logmon -f "strides_analytics.summary_export_$OLD"

echo " ### fix summary_export for NIH"
    QUERY=$(cat <<-ENDOFQUERY
    UPDATE strides_analytics.summary_export
    SET city_name='Bethesda',
    region_name='Maryland',
    country_code='US'
    WHERE domain like '%nih.gov%' and (city_name is null or city_name='Unknown')
ENDOFQUERY
)
    QUERY="${QUERY//\\/}"
    bq query --use_legacy_sql=false --batch=true "$QUERY"



echo " ###  export to GS"
    gsutil rm -f "gs://logmon_export/detail/detail.$DATE.*.json.gz" || true
#    bq extract \
#    --destination_format NEWLINE_DELIMITED_JSON \
#    --compression GZIP \
#    'strides_analytics.detail_export' \
#    "gs://logmon_export/detail/detail.$DATE.*.json.gz"

    gsutil rm -f "gs://logmon_export/summary/summary.$DATE.*.json.gz" || true
    bq extract \
    --destination_format NEWLINE_DELIMITED_JSON \
    --compression GZIP \
    'strides_analytics.summary_export' \
    "gs://logmon_export/summary/summary.$DATE.*.json.gz"

    gsutil rm -f "gs://logmon_export/uniq_ips/uniq_ips.$DATE.*.json.gz" || true
    bq extract \
    --destination_format NEWLINE_DELIMITED_JSON \
    --compression NONE \
    'strides_analytics.uniq_ips' \
    "gs://logmon_export/uniq_ips/uniq_ips.$DATE.json"



echo " ###  copy to filesystem"
#    mkdir -p "$PANFS/detail"
#    cd "$PANFS/detail" || exit
#    rm -f "$PANFS"/detail/detail."$DATE".* || true
#    gsutil cp -r "gs://logmon_export/detail/detail.$DATE.*" "$PANFS/detail/"

#    mkdir -p "$PANFS/summary"
#    cd "$PANFS/summary" || exit
#    rm -f "$PANFS"/summary/summary."$DATE".* || true
#    gsutil cp -r "gs://logmon_export/summary/summary.$DATE.*" "$PANFS/summary/"

    mkdir -p "$PANFS/uniq_ips"
    cd "$PANFS/uniq_ips" || exit
    rm -f "$PANFS"/uniq_ips/uniq_ips."$DATE".* || true
    gsutil cp -r "gs://logmon_export/uniq_ips/uniq_ips.$DATE.*" "$PANFS/uniq_ips/"

date
