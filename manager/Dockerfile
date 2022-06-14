FROM scylladb/scylla-manager-agent:2.6.3 as agent
FROM scylladb/scylla:4.6.3

COPY --from=agent /usr/bin/scylla-manager-agent /usr/bin/
RUN echo "[program:scylla-manager-agent]\n\
command=/usr/bin/scylla-manager-agent\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0" > /etc/supervisord.conf.d/scylla-manager-agent.conf
RUN mkdir -p /etc/scylla-manager-agent && echo "auth_token: token\n\
s3:\n\
    access_key_id: minio\n\
    secret_access_key: minio123\n\
    provider: Minio\n\
    endpoint: http://minio:9000" > /etc/scylla-manager-agent/scylla-manager-agent.yaml
