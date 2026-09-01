### 15:15–16:45 — Capstone: A Real Test → Build → Push Pipeline
*(Activity: 90 min)*

The main event, tying the day — and the course so far — together. You're building one pipeline that, automatically on a push to Git: **checks out a Node app, installs it and runs its tests, builds a Docker image, and pushes that image to Docker Hub.** That's the genuine shape of how real teams ship software.

Work individually or in pairs. Get the core pipeline green first; stretch goals if you race ahead.

**NOTE FOR TRAINERS** <br>
Tell them the split explicitly at the start: **Parts 0–1 are setup, Part 2 is reading, Part 3 is where it gets real.** The `Jenkinsfile` gets pasted from Slack — there's no learning in transcribing Groovy, and one missing brace costs twenty minutes. Protect time for Part 3, because the moment a build triggers itself from a `git push` is the moment the day lands. <br>
**END OF NOTE**

---

#### Part 0 (≈10 min) — Get the app and a Docker Hub token ready

**1. Clone your fork.**

*(Run from `~/jenkins-training`)*
```bash
git clone https://github.com/<your-username>/<your-fork>.git
cd <your-fork>/app
```

*(Run from `~/jenkins-training/<your-fork>/app`)*
```bash
ls
cat package.json
cat test.js
cat Dockerfile
```

A small Express app with a passing test and a Dockerfile. **Read `test.js` properly** — it's deliberately simple, and note the last few lines:

```javascript
if (failures > 0) {
  process.exit(1);        // NON-ZERO = the pipeline will fail
}
process.exit(0);          // ZERO = success
```


You've learnt Jest, whether the test runner is Jest, Vitest or another testing library, they do the same thing. <br>

Every test runner exits non-zero when tests fail. You've never needed to care, because you read the red output on your own screen. In a pipeline **nobody is reading the screen**, so that exit code is the only signal that reaches Jenkins. It's the Session 2 contract again, and it's why the command `npm run test` works as a pipeline stage with no extra wiring.

**2. Get a Docker Hub access token.**

*(In your browser — [hub.docker.com](https://hub.docker.com))*
- **Account Settings → Personal Access Tokens → Generate New Token**
- Description, permissions **Read & Write**, **Generate**
- **Copy the Personal Access Token now** — Docker Hub shows it once

This token is what the pipeline pushes with — **never** your account password. A token can be revoked independently without changing your login.

---

#### Part 1 (≈10 min) — Store your Docker Hub credentials in Jenkins

*(In the Jenkins UI — Dashboard)*
- **Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials**
- **Kind**: `Username with password`
- **Username**: your Docker Hub username
- **Password**: the access token
- **ID**: `dockerhub-credentials` ← **this exact string**, because the `Jenkinsfile` refers to it by ID
- **Description**: e.g. "Docker Hub push token"
- **Create**

**Checkpoint question:** why did we put the token *here* and not in the `Jenkinsfile` we're about to commit to Git?

---

#### Part 2 (≈25 min) — Write the pipeline

*(Run from `~/03-jenkins-cicd/`)*
- Run: `touch Jenkinsfile`
- Then: `code Jenkinsfile`

Your repo tree should look like:
```bash
.
├── app
│   ├── Dockerfile
│   ├── index.js
│   ├── package.json
│   └── test.js
└── Jenkinsfile
```

Copy, replacing `your-dockerhub-username`:

```groovy
pipeline {
    agent any

    environment {
        IMAGE_NAME = "your-dockerhub-username/hello-pipeline-app"
        IMAGE_TAG  = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "Building ${IMAGE_NAME}:${IMAGE_TAG}"
            }
        }

        stage('Install & Test') {
            agent {
                docker { image 'node:20' }
            }
            steps {
                dir('app') {
                    sh 'npm install'
                    sh 'npm test'
                }
            }
        }

        stage('Build Image') {
            steps {
                dir('app') {
                    sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG .'
                }
            }
        }

        stage('Push Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    sh 'docker push $IMAGE_NAME:$IMAGE_TAG'
                }
            }
        }
    }

    post {
        success {
            echo "Done! Pushed ${IMAGE_NAME}:${IMAGE_TAG} to Docker Hub."
        }
        failure {
            echo 'Pipeline failed — check which stage went red in the Stage View.'
        }
    }
}
```

**Read it together before running it.** Each new piece connects to something you know:

**`checkout scm`** — checks out the same repository this `Jenkinsfile` came from. You don't specify the URL again; Jenkins already knows it. `scm` is a variable Jenkins provides holding your source-control config.

**`dir('app')`** — runs the enclosed steps **inside that subfolder**. Our app lives in `app/`, not the repo root. It's `cd app` for a block of steps, and it puts you back afterwards.

**A stage with its own `agent`:**
```groovy
stage('Install & Test') {
    agent {
        docker { image 'node:20' }
    }
```
The top-level `agent any` sets the default, but **an individual stage can override it**. This stage runs *inside a freshly-started `node:20` container* — Jenkins pulls the image, starts it, mounts the workspace in, runs the steps, throws it away.


Why bother? Jenkins could just have Node installed. <br>

Because then **every project on that Jenkins shares one Node version**, and upgrading it for one team breaks another. With a per-stage Docker agent, each project declares the exact environment it needs, in its own `Jenkinsfile`, and gets a clean one every build. It's the "works on my machine" problem solved at the CI layer — the same argument that made you containerise your apps in the first place, applied one level up.

**Tagging with the build number:**
```groovy
IMAGE_TAG  = "${BUILD_NUMBER}"
```
Every image is tagged with the build that produced it, so you can trace any running container back to an exact build, and to the exact commit that build checked out. The `$BUILD_NUMBER` you met this morning, doing real work.

**The two quoting styles, side by side.** In `environment` we use Groovy double quotes so `${BUILD_NUMBER}` is substituted. In `sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG .'` we use **single** quotes with `$VAR` — there the *shell* substitutes, because Jenkins exports everything in `environment` as real shell environment variables. Both work. Single quotes in `sh` steps are safer, for the reason immediately below.

**`withCredentials` — the vault, used properly:**
```groovy
withCredentials([usernamePassword(
    credentialsId: 'dockerhub-credentials',
    usernameVariable: 'DOCKER_USER',
    passwordVariable: 'DOCKER_PASS'
)]) {
    // secrets exist ONLY inside this block
}
```
- `credentialsId:` — matches the **ID** from Part 1
- `usernameVariable:` / `passwordVariable:` — names the values get bound to
- Inside the `{ }` you can use `$DOCKER_USER` and `$DOCKER_PASS`; **outside they don't exist**
- Jenkins **masks** these in the console log — you see `****`

**ASK YOURSELF** <br>
Given Jenkins masks the values anyway, why do the docs insist on **single** quotes in `sh` steps that use secrets? <br>
**ANSWER** <br>
Because with **double** quotes, Groovy substitutes the secret's value into the command string *before* handing it to the shell — so the literal secret can end up in a process listing, or in a stack trace if the step errors. With single quotes, Groovy passes `$DOCKER_PASS` through untouched and the **shell** resolves it from the environment, so the value never appears in the command Groovy built. Masking catches most leaks; single quotes prevent one it can't.

**`--password-stdin`:**
```bash
echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
```
The pipe from Session 2. Rather than putting the password on the command line — where it appears in process listings — we pipe it in via standard input.

Now commit and push:

*(Run from root of repo)*
```bash
git add .
git commit -m "Add build and push pipeline"
git push 
```


---

#### Part 3 (≈35 min) — Point Jenkins at it and run it

*(In the Jenkins UI — Dashboard)*
1. **New Item** → `build-and-push` → **Pipeline** → **OK**
2. **Pipeline** section:
   - **Definition**: `Pipeline script from SCM`
   - **SCM**: `Git`
   - **Repository URL**: your repo's HTTPS URL
   - **Branch Specifier**: `*/main`
   - **Script Path**: `Jenkinsfile`
3. Scroll up to **Triggers** → tick **Poll SCM** → **Schedule**: `H/2 * * * *`
4. **Save**
5. **Manage Jenkins → **Available plugins** → Search: `Docker Pipeline` → Select + Install → Select 'Go back to top of page' → **Build Now** for the first run
5. Watch the **Stage View** march through Checkout → Install & Test → Build Image → Push Image

*(In your browser — [hub.docker.com](https://hub.docker.com))*
6. When green, confirm the image is in your Docker Hub repositories, tagged with the build number

**Now the moment that matters:**

*(Run from root of repo)*
```bash
echo "A trivial change" >> README.md
git add .
git commit -m "Trigger the pipeline"
git push 
```

Then **wait**. Within a couple of minutes Poll SCM kicks off a build **on its own**. A build you didn't start, triggered purely by a Git push. Sit with that — it's the whole point of the day.

**ASK YOURSELF** <br>
Click on the build drop down menu and select **'Pipeline Overview'**, look at your stage order: Test comes *before* Build and Push. What does that ordering actually protect you from? <br>
**ANSWER** <br>
If the tests fail, the pipeline stops there and **never builds or pushes the image**. A broken version physically cannot reach Docker Hub, because the gate caught it. Same principle as your `containerise` script checking exit codes. And there's a second reason: **the tests are the cheapest stage.** Running them first means a broken commit fails in thirty seconds rather than after a three-minute image build. Cheapest checks first is a design habit that scales all the way up.

---

#### Part 4 — Stretch goals

1. **Prove the gate works.** Add a stage *before* Build Image that deliberately fails (`sh 'exit 1'`), push it, and confirm nothing gets built or pushed. Then remove it. Worth doing — *seeing* the pipeline refuse to ship broken code is more convincing than being told it will
2. **Break the test instead.** Edit `app/test.js` so an assertion genuinely fails, push, and watch the pipeline stop at Install & Test. This is the realistic version of stretch 1
3. **Add a `latest` tag.** In the Push stage, also tag and push `$IMAGE_NAME:latest` alongside the numbered tag
4. **Notify on failure.** Enrich the `failure` block to print the image name and the build URL, then read about the Slack/email plugins that do this for real


**Solution**

**Stretch 1 — proving the gate.** Insert between `Install & Test` and `Build Image`:

```groovy
stage('Deliberate Failure') {
    steps {
        echo 'About to fail on purpose...'
        sh 'exit 1'
    }
}
```

Stage View: Checkout ✅ → Install & Test ✅ → Deliberate Failure ❌ → **Build Image and Push Image never run**. Check Docker Hub — no new tag. Delete the stage and push to go green.

**Stretch 2 — break the test properly.** In `app/test.js`:

```javascript
check("app is exported", () => {
  assert.ok(false, "deliberately failing");   // was: assert.ok(app, ...)
});
```

Push it. The pipeline fails at **Install & Test**, and the Console Output shows your actual test failure message. **This is the more realistic demo** — it's what a genuine broken commit looks like, and it proves the whole chain: failing assertion → non-zero exit → red stage → nothing shipped. Revert it afterwards.

**Stretch 3 — a `latest` tag as well:**

```groovy
stage('Push Image') {
    steps {
        withCredentials([usernamePassword(
            credentialsId: 'dockerhub-credentials',
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
        )]) {
            sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
            sh 'docker push $IMAGE_NAME:$IMAGE_TAG'

            // Point 'latest' at this same image, then push that tag too
            sh 'docker tag $IMAGE_NAME:$IMAGE_TAG $IMAGE_NAME:latest'
            sh 'docker push $IMAGE_NAME:latest'
        }
    }
}
```


**Stretch 4 — a more useful failure message:**

```groovy
post {
    success {
        echo "Done! Pushed ${IMAGE_NAME}:${IMAGE_TAG} to Docker Hub."
    }
    failure {
        echo "FAILED building ${IMAGE_NAME}:${IMAGE_TAG}"
        echo "Full log: ${BUILD_URL}console"
    }
    always {
        echo "Build ${BUILD_NUMBER} finished with status: ${currentBuild.currentResult}"
    }
}
```

`currentBuild.currentResult` is a built-in object holding this build's outcome — `SUCCESS`, `FAILURE` or `UNSTABLE`.


#### What to show at 16:45

Push a change, and via Poll SCM watch a build start on its own, go green through all stages, and produce a freshly-tagged image in your Docker Hub. Then explain, in your own words, **why the Test stage comes before the Push stage**.

<br>
<br>