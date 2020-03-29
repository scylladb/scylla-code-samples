# Scylla tutorial

To get it up and running start a local scylla instance started on port 9042:
```bash
docker run   -p 9042:9042/tcp   --name some-scylla   --hostname some-scylla   -d scylladb/scylla:3.3.0    --smp 1 --memory=750M --overprovisioned 1
```

Then run the code:
```bash
$ cargo run
```
