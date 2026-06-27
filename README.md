# vuln-node.js-express.js-app — CI/CD Pipeline

A deliberately vulnerable Node.js + Express app used as a real-world target for building an automated CI/CD pipeline with GitHub Actions, tested locally using **act**.

---

## Stack

| Layer | Technology |
|---|---|
| Runtime | Node.js 18 |
| Framework | Express.js |
| Database | SQLite (Sequelize) |
| Containerization | Docker |
| CI/CD | GitHub Actions |
| Local CI runner | act |
| Testing | Mocha |
| Linting | ESLint |
| Security | npm audit |

---

## Pipeline

```
push / pull request → main
        │
        ▼
┌── test ──┬── linting ──┬── security ──┐  (parallel)
└──────────┴─────────────┴──────────────┘
        │ all pass
        ▼
      build
        │
        ▼
      deploy
```

---

## Run Locally with act

**Install act:**
```bash
cd /tmp
wget https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz
tar -xzf act_Linux_x86_64.tar.gz
sudo mv act /usr/local/bin/act
```

**Create `~/.actrc`:**
```
--privileged
-P ubuntu-latest=catthehacker/ubuntu:act-latest
--container-daemon-socket /var/run/docker.sock
```

**Run:**
```bash
act              # full pipeline
act -j deploy    # specific job
```

---

## Environment Variables

All optional — app has defaults for everything.

| Variable | Default |
|---|---|
| `APP_PORT` | `5000` |
| `NODE_ENV` | `development` |
| `JWT_SECRET` | `superSecretPassword` |
| `DATABASE_DIALECT` | `sqlite` |

---

## Troubleshooting

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for all errors encountered during setup with causes and fixes.

---

**Author:** Khoulid Akram — ENSA Safi, DevOps 2025/2026
