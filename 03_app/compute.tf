data "aws_ami" "amzn2023" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

resource "aws_instance" "producer" {
  ami                         = data.aws_ami.amzn2023.id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.sqs_send_msg.name
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnets.private.ids[0]

  user_data = <<-EOF
              #!/bin/bash
              # Script to create systemd service and timer for sending SQS messages
              cat <<'SERVICE' >/etc/systemd/system/send_sqs_message.service
              [Unit]
              Description=Send an SQS message

              [Service]
              Type=oneshot
              ExecStart=/usr/local/bin/send_sqs_message.sh
              SERVICE

              cat <<'TIMER' >/etc/systemd/system/send_sqs_message.timer
              [Unit]
              Description=Run send_sqs_message service every minute

              [Timer]
              OnCalendar=*-*-* *:*:00
              
              [Install]
              WantedBy=timers.target
              TIMER

              cat <<'SCRIPT' >/usr/local/bin/send_sqs_message.sh
              #!/bin/bash
              AWS_REGION="${data.aws_region.current.name}"
              SQS_URL="${aws_sqs_queue.heartbeat.url}"

              CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")

              MESSAGE_BODY=$(jq -n --arg serviceID "producer.server1" --arg sentTime "$CURRENT_TIME" '{
                HeartBeat: {
                  ServiceID: $serviceID,
                  SentTime: $sentTime
                }
              }')

              aws sqs send-message --queue-url "$SQS_URL" --message-body "$MESSAGE_BODY" --region "$AWS_REGION"
              SCRIPT

              chmod +x /usr/local/bin/send_sqs_message.sh
              systemctl daemon-reload
              systemctl enable send_sqs_message.timer
              systemctl start send_sqs_message.timer
              EOF

  vpc_security_group_ids = [
    data.aws_security_group.ssh.id
  ]

  tags = {
    Name = "producer-${local.suffix}"
  }
}

data "dns_a_record_set" "rds_main" {
  host = aws_db_instance.main.address
}

resource "aws_instance" "jumphost" {
  ami                         = data.aws_ami.amzn2023.id
  associate_public_ip_address = false
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnets.private.ids[0]

  user_data = <<-EOF
              #!/bin/bash -xe
              hostnamectl set-hostname jumphost
              yum update -y
              yum install -y nc mtr postgresql15

              export PGDATABASE="${local.db.name}"
              export PGHOSTADDR="${tolist(data.dns_a_record_set.rds_main.addrs)[0]}"

              export PGADMIN="dbadmin"
              export PGPASSWORD="${jsondecode(aws_secretsmanager_secret_version.rds_dbadmin.secret_string)["dbadmin"]}"

              export DB_WUSER_USERNAME="wuser"
              export DB_WUSER_PASSWORD="${jsondecode(aws_secretsmanager_secret_version.rds_wuser.secret_string)["wuser"]}"

              export DB_RUSER_USERNAME="ruser"
              export DB_RUSER_PASSWORD="${jsondecode(aws_secretsmanager_secret_version.rds_ruser.secret_string)["ruser"]}"

              export SCHEMA_NAME="hb"

              psql -h $PGHOSTADDR -U $PGADMIN -d $PGDATABASE -c "
              DO \$\$
              BEGIN
                  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_WUSER_USERNAME') THEN
                      CREATE ROLE \"$DB_WUSER_USERNAME\" WITH LOGIN PASSWORD '$DB_WUSER_PASSWORD';
                  END IF;

                  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_RUSER_USERNAME') THEN
                      CREATE ROLE \"$DB_RUSER_USERNAME\" WITH LOGIN PASSWORD '$DB_RUSER_PASSWORD';
                  END IF;

                  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = '$SCHEMA_NAME') THEN
                      CREATE SCHEMA \"$SCHEMA_NAME\";
                  END IF;

                  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = '$SCHEMA_NAME' AND tablename = 'soh') THEN
                      CREATE TABLE \"$SCHEMA_NAME\".soh (
                          serverID TEXT PRIMARY KEY,
                          timeReceived timestamp(6)  WITH TIME ZONE NOT NULL
                      );
                  END IF;

                  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_WUSER_USERNAME') THEN
                      EXECUTE 'GRANT CONNECT ON DATABASE \"$PGDATABASE\" TO \"$DB_WUSER_USERNAME\"';
                      EXECUTE 'GRANT USAGE ON SCHEMA \"$SCHEMA_NAME\" TO \"$DB_WUSER_USERNAME\"';
                      EXECUTE 'GRANT ALL ON ALL TABLES IN SCHEMA \"$SCHEMA_NAME\" TO \"$DB_WUSER_USERNAME\"';
                      EXECUTE 'GRANT ALL ON ALL SEQUENCES IN SCHEMA \"$SCHEMA_NAME\" TO \"$DB_WUSER_USERNAME\"';
                  END IF;

                  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_RUSER_USERNAME') THEN
                      EXECUTE 'GRANT CONNECT ON DATABASE \"$PGDATABASE\" TO \"$DB_RUSER_USERNAME\"';
                      EXECUTE 'GRANT USAGE ON SCHEMA \"$SCHEMA_NAME\" TO \"$DB_RUSER_USERNAME\"';
                      EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA \"$SCHEMA_NAME\" TO \"$DB_RUSER_USERNAME\"';
                  END IF;
              END;
              \$\$;
              "
              EOF

  vpc_security_group_ids = [
    data.aws_security_group.ssh.id
  ]

  tags = {
    Name = "jumphost-${local.suffix}"
  }

  depends_on = [
    aws_db_instance.read
  ]
}
