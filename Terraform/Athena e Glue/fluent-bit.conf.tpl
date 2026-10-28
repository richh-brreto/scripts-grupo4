[SERVICE]
    Flush        5
    Log_Level    info

[INPUT]
    Name         tail
    Path         ${log_path}
    Tag          app

[FILTER]
    Name         record_modifier
    Match        *
    Record       host $${HOSTNAME}

[OUTPUT]
    Name                 s3
    Match                *
    bucket               ${bucket}
    region               ${region}
    total_file_size      50M
    upload_timeout       5m
    use_put_object       On
    compression          gzip
    s3_key_format        /logs/year=%Y/month=%m/day=%d/hour=%H/$UUID.json.gz
    store_dir            /var/lib/fluent-bit/s3
