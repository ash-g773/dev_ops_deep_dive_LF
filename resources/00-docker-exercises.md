# Docker — Inside Containers, and Data That Lasts

A guided walkthrough. **Follow it top to bottom**, typing the commands as you go — every one is explained straight afterwards.

You've already run other people's containers, built your own images, seen layer caching, and had two containers talk to each other. This picks up from there.

| Part | What you'll learn | Time |
|---|---|---|
| **1** | Getting inside a running container | 20 min |
| **2** | Why your changes keep disappearing | 10 min |
| **3** | Named volumes — data that survives | 25 min |
| **4** | Bind mounts — editing code live | 20 min |
| **5** | Configuration without rebuilding | 20 min |
| **6** | Keeping containers alive | 25 min |
| **7** | Housekeeping | 10 min |

Work in a scratch folder:

```bash
mkdir -p ~/docker-lab && cd ~/docker-lab
```

---

# Part 1 — Getting inside a running container

**A container is a real Linux system.** You can open a shell in it and look around, exactly like SSH-ing into a server — which is enormously useful when something isn't working.

### Start something to poke at

```bash
docker run -d --name web -p 8080:80 nginx:alpine
```

| Flag | What it does |
|---|---|
| `-d` | detached — runs in the background and gives you your prompt back |
| `--name web` | names it, so you can refer to it as `web` instead of a random ID |
| `-p 8080:80` | your port 8080 → the container's port 80 |

Check it's up, then visit `http://localhost:8080`:

```bash
docker ps
```

### Open a shell inside it

```bash
docker exec -it web sh
```

Your prompt changes to something like `/ #`. **You are now inside the container.**

| Part | What it does |
|---|---|
| `docker exec` | run a command in an ALREADY-RUNNING container |
| `-i` | interactive — keep the input stream open so you can type |
| `-t` | allocate a terminal, so you get a proper prompt |
| `web` | which container |
| `sh` | the command to run — here, a shell |

> `-it` together is what makes it feel like a terminal session. Try `docker exec web sh` without them and watch it exit immediately — there's no terminal for the shell to attach to.

### Have a look around

Type these one at a time:

```sh
ls /usr/share/nginx/html
```
The web server's files. This is where nginx serves from.

```sh
cat /usr/share/nginx/html/index.html
```
The default page you saw in the browser.

```sh
ps aux
```
**Count the processes.** There are two or three, not the two hundred on your laptop. A container isn't a small virtual machine — it's usually **one process** and its children.

```sh
cat /etc/os-release
```
Alpine Linux. The container has its own distribution, independent of whatever your machine runs.

```sh
whoami
```
`root` — inside this container. That's the default, and it's something you'd change in production. More on that later.

```sh
df -h
```
Its own filesystem, with its own sizes.

Leave the container:

```sh
exit
```

You're back on your own machine. **The container is still running** — `exit` left the shell, not the container.

### Two more ways to see inside

You don't always need a shell. These read information from outside:

```bash
docker logs web
```
Everything the container has printed to standard output. **This is the first thing to check when a container won't start** — if it crashed, the reason is almost always here.

```bash
docker logs -f web
```
Follow the logs live. Refresh `localhost:8080` in your browser and watch requests appear. `Ctrl+C` to stop watching.

```bash
docker inspect web
```
A large JSON dump: ports, mounts, environment variables, network settings, the command it runs. Too much to read raw, so filter it:

```bash
docker inspect --format='{{.State.Status}}' web
docker inspect --format='{{.NetworkSettings.IPAddress}}' web
```

```bash
docker stats web
```
Live CPU and memory usage. `Ctrl+C` to exit.

### Try it yourself

1. Open a shell in `web` and find the nginx **configuration** file (hint: look in `/etc/nginx`)
2. Use `docker logs -f` while refreshing the page a few times. What gets logged?
3. Use `docker inspect` to find which host port maps to the container's port 80

---

# Part 2 — Why your changes keep disappearing

**10 minutes, and it sets up everything after it.**

### Change something from inside

```bash
docker exec -it web sh
```

```sh
echo "<h1>I changed this</h1>" > /usr/share/nginx/html/index.html
exit
```

Refresh `localhost:8080`. **Your change is there.**

### Now destroy the container and start a fresh one

```bash
docker rm -f web
docker run -d --name web -p 8080:80 nginx:alpine
```

Refresh again. **Your change is gone.**

### What actually happened

An image is **read-only**. When you run a container, Docker adds a thin **writable layer** on top — every change you make goes there.

```
   ┌─────────────────────────────┐
   │  writable container layer   │  ← your edit lived here
   ├─────────────────────────────┤
   │  nginx:alpine image         │  ← read-only, never changes
   └─────────────────────────────┘
```

`docker rm` deletes the container **and its writable layer**. The image is untouched, so the new container starts from the original files again.

> This is a feature, not a bug. It's why a container gives you the same starting point every single time — and it's exactly the same reason a fresh CI build is reliable.

**But a database can't work this way.** If your data lives in the writable layer, you lose everything the moment the container is replaced — which happens on every deployment. That's what Part 3 fixes.

```bash
docker rm -f web
```

---

# Part 3 — Named volumes: data that survives

**25 minutes.** A **volume** is storage that Docker manages, living *outside* any container. Containers come and go; the volume stays.

### First, watch data disappear

```bash
docker run -d --name db -e POSTGRES_PASSWORD=secret postgres:16-alpine
```

Wait about five seconds for Postgres to finish starting, then:

```bash
docker exec -it db psql -U postgres -c "CREATE TABLE things (id int, name text);"
docker exec -it db psql -U postgres -c "\dt"
```

| Part | What it does |
|---|---|
| `docker exec -it db` | run something inside the `db` container |
| `psql -U postgres` | the Postgres client, as the `postgres` user |
| `-c "..."` | run this one SQL statement and exit |
| `\dt` | list tables |

You should see your `things` table. Now replace the container:

```bash
docker rm -f db
docker run -d --name db -e POSTGRES_PASSWORD=secret postgres:16-alpine
sleep 5
docker exec -it db psql -U postgres -c "\dt"
```

**`Did not find any relations.`** The table is gone, for exactly the reason in Part 2.

### Now create a volume and use it

```bash
docker rm -f db
docker volume create pgdata
```

That creates a named volume called `pgdata`. Now start Postgres with it attached:

```bash
docker run -d --name db \
  -v pgdata:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:16-alpine
```

**The important flag:**

```
-v pgdata:/var/lib/postgresql/data
   ▲       ▲
   │       └── the path INSIDE the container
   └────────── the volume name on your machine
```

`/var/lib/postgresql/data` is where Postgres keeps its files. We're telling Docker: *anything written there goes into the `pgdata` volume, not the container's writable layer.*

Create the table again:

```bash
sleep 5
docker exec -it db psql -U postgres -c "CREATE TABLE things (id int, name text);"
docker exec -it db psql -U postgres -c "INSERT INTO things VALUES (1, 'hello');"
docker exec -it db psql -U postgres -c "SELECT * FROM things;"
```

### Now destroy the container — and get the data back

```bash
docker rm -f db

docker run -d --name db \
  -v pgdata:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:16-alpine

sleep 5
docker exec -it db psql -U postgres -c "SELECT * FROM things;"
```

**Your row is still there.** The container was destroyed and rebuilt; the data outlived it.

### Have a look at the volume itself

```bash
docker volume ls
docker volume inspect pgdata
```

The `Mountpoint` shows where Docker keeps it on disk. **Don't edit it directly** — go through a container.

### Volumes have their own lifecycle

```bash
docker rm -f db          # container gone
docker volume ls         # pgdata is still here
```

That's the whole point. To remove it deliberately:

```bash
docker volume rm pgdata     # only works if nothing is using it
```

Recreate it before continuing:

```bash
docker volume create pgdata
```

### Try it yourself

4. Start two *different* Postgres containers, both using `pgdata`. What happens? (Postgres will complain — read the logs and work out why)
5. Create a volume called `myvol`, attach it to an `alpine` container at `/data`, write a file into it, destroy the container, then attach the same volume to a **new** container and read the file back
6. What does `docker volume prune` do? Check the help text before running it

---

# Part 4 — Bind mounts: editing code live

**20 minutes.** A **bind mount** points a path inside the container at a real folder on *your* machine. Changes on either side are visible immediately.

### Make a folder with a file in it

```bash
mkdir -p ~/docker-lab/site
echo "<h1>Version one</h1>" > ~/docker-lab/site/index.html
```

### Mount it into nginx

```bash
docker run -d --name site -p 8081:80 \
  -v ~/docker-lab/site:/usr/share/nginx/html \
  nginx:alpine
```

Same `-v` flag, but the left-hand side is now **a path** rather than a name:

```
-v ~/docker-lab/site:/usr/share/nginx/html
   ▲                  ▲
   │                  └── path inside the container
   └───────────────────── a real folder on YOUR machine
```

> **The rule:** if the left side starts with `/` or `~`, it's a **bind mount**. Otherwise it's a **named volume**.

Visit `http://localhost:8081` — "Version one".

### Now edit the file on your machine

Without touching the container at all:

```bash
echo "<h1>Version two</h1>" > ~/docker-lab/site/index.html
```

Refresh the browser. **It changed instantly.** No rebuild, no restart.

### It works the other way too

```bash
docker exec -it site sh
```

```sh
echo "<h1>Written from inside</h1>" > /usr/share/nginx/html/index.html
exit
```

```bash
cat ~/docker-lab/site/index.html
```

The file on **your** machine changed. It's genuinely the same folder, seen from two places.

### Named volume or bind mount?

| | Named volume | Bind mount |
|---|---|---|
| **Where** | Docker manages it, somewhere internal | A folder you choose, on your machine |
| **Written as** | `-v pgdata:/path` | `-v /host/path:/path` |
| **Survives `docker rm`** | Yes | Yes — it's your folder |
| **Portable** | Yes — works on any machine | No — depends on your paths |
| **Use it for** | Databases, uploads, anything the app owns | Live-editing source code in development |

> **In production you use volumes, not bind mounts.** A bind mount ties the container to one machine's directory layout, which defeats most of the point of containers.

### Try it yourself

7. Bind-mount a folder into an `alpine` container at `/data` and create a file from inside. Check it appeared on your machine
8. Try mounting a folder that **doesn't exist**. What does Docker do?
9. Add `:ro` to the end of a bind mount — `-v ~/docker-lab/site:/usr/share/nginx/html:ro`. Try writing from inside. What happens, and when would you want this?

```bash
docker rm -f site
```

---

# Part 5 — Configuration without rebuilding

**20 minutes.** The same image should run in dev, test and production. What changes between them is **configuration**, and configuration goes in at run time.

### Build something that reads its environment

```bash
mkdir -p ~/docker-lab/configapp && cd ~/docker-lab/configapp
```

**`app.js`** — create this file:

```javascript
const http = require("http");

const PORT = process.env.PORT || 3000;
const GREETING = process.env.GREETING || "Hello";
const ENVIRONMENT = process.env.ENVIRONMENT || "unknown";

http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(`${GREETING} from the ${ENVIRONMENT} environment\n`);
}).listen(PORT, () => console.log(`Listening on ${PORT}`));
```

`process.env.GREETING` reads an environment variable. The `|| "Hello"` gives a fallback if it isn't set.

**`Dockerfile`** — create this file:

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY app.js .
ENV PORT=3000
EXPOSE 3000
CMD ["node", "app.js"]
```

| Line | What it does |
|---|---|
| `ENV PORT=3000` | bakes a DEFAULT into the image — overridable at run time |
| `EXPOSE 3000` | documentation only. It does **not** publish the port — `-p` does that |

Build it:

```bash
docker build -t configapp .
```

### Run the same image three different ways

```bash
docker run -d --name dev -p 3001:3000 \
  -e GREETING="Morning" -e ENVIRONMENT="development" configapp

docker run -d --name test -p 3002:3000 \
  -e GREETING="Hello" -e ENVIRONMENT="test" configapp

docker run -d --name prod -p 3003:3000 \
  -e GREETING="Welcome" -e ENVIRONMENT="production" configapp
```

```bash
curl localhost:3001
curl localhost:3002
curl localhost:3003
```

Three different behaviours. **One image, built once.** That's the whole idea — the artifact you tested is the artifact you ship.

### When there are a lot of variables

Typing six `-e` flags gets old. Put them in a file instead:

**`dev.env`** — create this file:

```
GREETING=Morning
ENVIRONMENT=development
PORT=3000
```

```bash
docker rm -f dev
docker run -d --name dev -p 3001:3000 --env-file dev.env configapp
curl localhost:3001
```

> **Never commit a `.env` file containing real secrets.** Add it to `.gitignore`. Configuration files like this are for values, and production secrets belong in a proper secret store.

### Check what a container actually got

```bash
docker exec dev env
```

Lists every environment variable inside it — useful when something isn't picking up a value you thought you'd set.

### Try it yourself

10. Run a fourth container with **no** `-e` flags at all. What does it say, and why?
11. Set `PORT=4000` via `-e` and map `-p 3004:4000`. Does it still work?
12. What's the difference between `ENV` in a Dockerfile and `-e` at run time? Which wins?

```bash
docker rm -f dev test prod
```

---

# Part 6 — Keeping containers alive

**25 minutes.** Containers stop. Processes crash, machines reboot. Docker can react to both.

### Restart policies

```bash
docker run -d --name flaky --restart unless-stopped alpine \
  sh -c "sleep 10 && exit 1"
```

This container sleeps ten seconds then exits with an error. Watch what happens:

```bash
docker ps
sleep 12
docker ps
```

**It came back.** Docker restarted it, because of `--restart unless-stopped`.

| Policy | Behaviour |
|---|---|
| `no` | the default — never restart |
| `on-failure` | restart only if it exits non-zero |
| `on-failure:3` | ...and give up after three attempts |
| `always` | restart whatever happens, including after a machine reboot |
| `unless-stopped` | like `always`, but respects a manual `docker stop` |

```bash
docker rm -f flaky
```

### Healthchecks

A restart policy only knows whether the **process** is alive. A process can be running and still be useless — hung, out of memory, unable to reach its database. A **healthcheck** tests whether it's actually working.

```bash
cd ~/docker-lab/configapp
```

Update your **`Dockerfile`** — add the `HEALTHCHECK` line:

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY app.js .
ENV PORT=3000
EXPOSE 3000

# NEW — check the app actually responds, every 10 seconds
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --spider -q http://localhost:3000 || exit 1

CMD ["node", "app.js"]
```

| Option | What it means |
|---|---|
| `--interval=10s` | how often to check |
| `--timeout=3s` | how long to wait before calling the check failed |
| `--start-period=5s` | grace period at startup — failures here don't count |
| `--retries=3` | how many consecutive failures before it's marked unhealthy |
| `CMD ... \|\| exit 1` | the check itself. Exit 0 = healthy, anything else = not |

> `wget --spider` fetches the page without saving it. The `|| exit 1` is the exit-code contract again — Docker only cares whether the command succeeded.

Rebuild and run:

```bash
docker build -t configapp .
docker run -d --name healthy -p 3005:3000 configapp
```

Watch the status change:

```bash
docker ps
```

For the first few seconds you'll see `health: starting`, then `(healthy)`.

```bash
docker inspect --format='{{.State.Health.Status}}' healthy
```

### Now break it on purpose

```bash
docker exec healthy sh -c "pkill node" || true
sleep 15
docker ps -a
```

The process is dead, so the healthcheck fails.

### Try it yourself

13. Add `--restart on-failure` to the `healthy` container and kill the process again. What's different?
14. Change `--interval` to `30s`, rebuild, and see how much longer the status takes to change
15. Why is `--start-period` necessary? What would happen without it on a slow-starting app?

```bash
docker rm -f healthy
```

---

# Part 7 — Housekeeping

**10 minutes.** Docker uses more disk than you think. Stopped containers, unused images and orphaned volumes all sit there quietly.

### See what you're using

```bash
docker system df
```

| Row | What it is |
|---|---|
| **Images** | downloaded and built images |
| **Containers** | including stopped ones |
| **Local Volumes** | data volumes |
| **Build Cache** | layers kept to speed up rebuilds |

The **RECLAIMABLE** column is what you'd get back by cleaning up.

### See what's actually there

```bash
docker ps -a          # every container, including stopped
docker images         # every image
docker volume ls      # every volume
```

### Clean up, in increasing order of aggression

```bash
docker container prune       # remove all STOPPED containers
docker image prune           # remove dangling (untagged) images
docker builder prune         # clear the build cache
```

```bash
docker system prune          # all of the above at once
```

```bash
docker system prune -a --volumes     # ALSO unused images and volumes
```

> **That last one is destructive.** `--volumes` will delete database data you meant to keep. Run `docker volume ls` first and know what you're removing.

### Targeted removal

```bash
docker rm -f <name>          # one container
docker rmi <image>           # one image
docker volume rm <volume>    # one volume
docker rm -f $(docker ps -aq)   # every container at once
```

### Try it yourself

16. Run `docker system df` before and after `docker container prune`. How much did you reclaim?
17. What's a "dangling" image, and how does one get created?
18. Why do volumes survive a plain `docker system prune`?

---

## Where you got to

- [ ] You can open a shell in a running container and look around
- [ ] You can explain why edits made inside a container disappear
- [ ] You've used a **named volume** to survive `docker rm`
- [ ] You've used a **bind mount** to edit files live
- [ ] You can say when to use each
- [ ] You've run one image three ways using environment variables
- [ ] You've added a `HEALTHCHECK` and watched the status change
- [ ] You know how to see and reclaim Docker's disk usage

## Command reference

```bash
# looking inside
docker exec -it <name> sh          open a shell
docker logs <name>                 what it has printed
docker logs -f <name>              ...live
docker inspect <name>              full configuration as JSON
docker stats <name>                live CPU and memory

# volumes
docker volume create <name>
docker volume ls
docker volume inspect <name>
docker volume rm <name>
-v myvol:/path                     named volume
-v /host/path:/path                bind mount
-v /host/path:/path:ro             read-only bind mount

# configuration
-e KEY=value                       one variable
--env-file file.env                many
docker exec <name> env             what did it actually get?

# staying alive
--restart unless-stopped
HEALTHCHECK CMD <command> || exit 1
docker inspect --format='{{.State.Health.Status}}' <name>

# housekeeping
docker system df
docker container prune
docker system prune
docker rm -f $(docker ps -aq)
```

## Clean up

```bash
docker rm -f $(docker ps -aq)
docker system df
```

Leave `pgdata` and the `~/docker-lab` folder if you want to keep experimenting.
