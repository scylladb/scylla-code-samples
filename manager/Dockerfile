FROM scylladb/scylla-manager-agent:3.11.2 as agent
FROM scylladb/scylla:2026.2.1

USER root
COPY --from=agent /usr/bin/scylla-manager-agent /usr/bin/
RUN printf '[program:scylla-manager-agent]\ncommand=/usr/bin/scylla-manager-agent\nautorestart=true\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0\n' \
    > /etc/supervisord.conf.d/scylla-manager-agent.conf
RUN mkdir -p /etc/scylla-manager-agent && \
    printf 'auth_token: token\ns3:\n    access_key_id: minio\n    secret_access_key: minio123\n    provider: Minio\n    endpoint: http://minio:9000\n' \
    > /etc/scylla-manager-agent/scylla-manager-agent.yaml
USER scylla
