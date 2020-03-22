FROM scylladb/scylla:latest

RUN echo -e "#!/usr/bin/env bash\n\
set -eu -o pipefail\n\
if [[ ! -f \"/var/lib/scylla-manager/scylla_manager.crt\" || ! -f \"/var/lib/scylla-manager/scylla_manager.key\" ]]; then\n\
   /sbin/scyllamgr_ssl_cert_gen\n\
fi\n\
exec /usr/bin/scylla-manager-agent $@" > /scylla-manager-agent-docker-entrypoint.sh

RUN echo -e "[scylla-manager]\n\
name=Scylla Manager for Centos \$releasever - \$basearch\n\
baseurl=http://downloads.scylladb.com/manager/rpm/unstable/centos/branch-2.0/latest/scylla-manager/\7/\$basearch/\n\
enabled=1\n\
gpgcheck=0\n" > /etc/yum.repos.d/scylla-manager.repo

RUN echo -e "[program:scylla-manager-agent]\n\
command=/scylla-manager-agent-docker-entrypoint.sh\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0" > /etc/supervisord.conf.d/scylla-manager-agent.conf

RUN yum -y install epel-release && \
    yum -y clean expire-cache && \
    yum -y update && \
    yum install -y scylla-manager-agent && \
    yum clean all && \
    rm /etc/yum.repos.d/scylla-manager.repo

RUN echo -e "auth_token: token\n\
s3:\n\
    access_key_id: minio\n\
    secret_access_key: minio123\n\
    endpoint: http://minio:9000" > /etc/scylla-manager-agent/scylla-manager-agent.yaml

RUN rm -f /var/lib/scylla-manager/scylla_manager.crt && \
    rm -f /var/lib/scylla-manager/scylla_manager.key && \
    chmod --reference=/usr/bin/scylla-manager-agent /scylla-manager-agent-docker-entrypoint.sh
