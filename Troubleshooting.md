# Troubleshooting

All errors encountered while setting up the CI/CD pipeline for `vuln-node.js-express.js-app`.

---

## Error 1 — act Segmentation Fault on Startup

**Error:**
```
act --version
Segmentation fault (core dumped)
```

**Cause:**
Host machine was suspended while the VM was running. On wake-up, the system clock jumped ~7,500 seconds forward. This caused the Linux kernel's timers and memory management to fire all at once, corrupting process memory. Any binary running in this state will segfault.

**Diagnosis:**
```bash
dmesg | tail -20
# look for: "Radical host time change" and "general protection fault"
```

**Fix:**
```bash
sudo reboot
act --version
```

**Prevention:** Always shut down or pause the VM before putting the host to sleep.

---

## Error 2 — act Installed via Snap Causes Conflicts

**Error:**
```
snap.act.act-454fca7d.scope: Consumed 2.013s CPU time
# act fails to access Docker socket properly
```

**Cause:**
snap packages run in a confined sandbox with restricted access to system resources including the Docker socket. This causes silent failures when act tries to manage containers.

**Fix:**
```bash
sudo snap remove act

cd /tmp
wget https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz
tar -xzf act_Linux_x86_64.tar.gz
sudo mv act /usr/local/bin/act
act --version
```

---

## Error 3 — YAML Syntax Error

**Error:**
```
workflow is not valid. 'ci.yml':
yaml: line 68: did not find expected comment or line break
```

**Cause:**
Two mistakes on the same line:
1. Multiline command written on the same line as `|` — everything after `|` must go on the next line
2. Space in Docker image tag: `vuln-node: latest` — YAML reads this as a key-value pair

**Fix:**
```yaml
# Wrong
run: | docker run -d \ --name app \ vuln-node: latest

# Correct
run: |
  docker run -d \
    --name vuln-node-application \
    -p 5000:5000 \
    vuln-node:latest
```

---

## Error 4 — Dockerfile WORKDIR and COPY Order

**Error:**
```
=> ERROR [3/5] WORKDIR /application
mkdir /application: not a directory
```

**Cause:**
`COPY` came before `WORKDIR`. When two files are copied to a path that doesn't exist, Docker creates `/application` as a **file**. Then `WORKDIR` tries to treat it as a directory and fails.

**Fix:**
```dockerfile
# Wrong
COPY ./package.json ./package-lock.json /application
WORKDIR /application

# Correct — WORKDIR always first
WORKDIR /application
COPY ./package.json ./package-lock.json .
RUN npm ci
COPY . .
```

---

## Error 5 — Wrong CMD in Dockerfile

**Error:**
```
Error: Cannot find module '/application/start'
code: 'MODULE_NOT_FOUND'
```

**Cause:**
`CMD ["node", "start"]` tells Node to execute a **file** called `start`. That file doesn't exist — `start` is an npm script name, not a filename.

**Fix:**
```dockerfile
# Wrong
CMD ["node", "start"]

# Correct
CMD ["node", "src/server.js"]

# Also works
CMD ["npm", "start"]
```

---

## Error 6 — Permission Denied Creating app.log

**Error:**
```
sh: can't create app.log: Permission denied
```

**Cause:**
The npm start script redirects output to `app.log` (`> app.log 2> app_err.log`). The container runs as `USER node` but `/application` is owned by root — the node user has no write permission there.

**Fix:**
```dockerfile
# Add before USER node
RUN chown -R node:node /application
EXPOSE 5000
USER node
CMD ["node", "src/server.js"]
```

`chown -R` recursively gives the node user full ownership of the working directory.

---

## Error 7 — Permission Denied Creating uploads Directory

**Error:**
```
Error: EACCES: permission denied, mkdir '/application/uploads'
errno: -13
code: 'EACCES'
```

**Cause:**
The app uses `multer` for file uploads. On startup, multer tries to create `/application/uploads`. Same root cause as Error 6 — `USER node` doesn't own the directory.

**Fix:**
Same as Error 6 — the `chown -R node:node /application` line resolves both issues at once.

```bash
# After fixing Dockerfile, rebuild
docker build -t vuln-node .
docker rm -f vuln-node-application
docker run -d --name vuln-node-application -p 5000:5000 vuln-node:latest
docker logs vuln-node-application
```

---

## Error 8 — Container Name Conflict on Redeployment

**Error:**
```
docker: Error response from daemon: Conflict.
The container name "/vuln-node-application" is already in use
by container "ab2efcb790739d..."
```

**Cause:**
The previous pipeline run left a container named `vuln-node-application` still running on the host. The Docker socket mounts containers directly onto the host daemon where they persist after the act job finishes. Docker doesn't allow two containers to share the same name.

**Fix:**
Add a stop step before `docker run` in the CD job:

```yaml
- name: stop old container
  run: docker rm -f vuln-node-application 2>/dev/null || true

- name: run container
  run: |
    docker run -d \
      --name vuln-node-application \
      -p 5000:5000 \
      vuln-node:latest
```

`2>/dev/null || true` — suppresses errors if no container exists yet and prevents the job from failing.

---

## Error 9 — act Job Containers Stuck, Permission Denied on Cleanup

**Error:**
```
failed to remove container: Error response from daemon:
cannot remove container: could not kill container: permission denied
Error response from daemon: remove act-test-build-d5efed...:
volume is in use - [e78c6ab78ec3b87...]
```

**Cause:**
Without `--privileged`, act doesn't have enough permissions to kill and remove the containers it spawns. They get stuck running and block the next pipeline run.

**Fix — create `~/.actrc`:**
```
--privileged
-P ubuntu-latest=catthehacker/ubuntu:act-latest
--container-daemon-socket /var/run/docker.sock
```

**Fix — kill stuck containers via kernel PID:**
```bash
# get container PIDs and kill at OS level
docker ps | grep act | awk '{print $1}' | \
  xargs docker inspect --format '{{.State.Pid}}' | \
  xargs kill -9 2>/dev/null

# clean up Docker records
docker ps -a | grep act | awk '{print $1}' | xargs docker rm -f 2>/dev/null
docker volume prune -f
```

Why `kill -9` works when `docker rm -f` doesn't: `docker rm -f` sends the signal through the Docker daemon which is blocked by the volume lock. `kill -9` (SIGKILL) goes directly to the kernel — the process cannot catch or ignore it.
