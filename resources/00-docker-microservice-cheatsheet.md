# Microservice Database - MVC

This document should serve as a guide to how to create two microservices, a **database** and a **mvc** launched together via **docker-compose**.

An example of the overarching project structure could look similar to this:

```
.
├── docker-compose.yml
├── students-db
│   ├── Dockerfile
│   └── students.sql
└── students-mvc
    ├── Dockerfile
    ├── app.js
    ├── controllers
    │   └── students.js
    ├── db
    │   └── connect.js
    ├── index.js
    ├── logger.js
    ├── models
    │   └── Student.js
    ├── node_modules
    ├── package-lock.json
    ├── package.json
    └── router
        └── students.js
```

## Database Microservice

It's sensible to start defining the configuration for the database first and we need two files based in the same folder to achieve this.
- **Dockerfile**
- **<file-name>.sql**

### Dockerfile

The below code is used to build an image off of the base **postgres** image. 

```Dockerfile
# Base Image used to build image
FROM postgres 
# Sets the DB password
ENV POSTGRES_PASSWORD docker
# Sets the DB name
ENV POSTGRES_DB students
# Copies contents to 'students.sql' over to Image and DB entry point
COPY students.sql /docker-entrypoint-initdb.d/
```

### students.sql

We'll also need to define the schema and the seed information for the Database.

```sql
DROP TABLE IF EXISTS students;

CREATE TABLE students (
    student_id INT GENERATED ALWAYS AS IDENTITY,
    name text NOT NULL,
    deep_dive text NOT NULL,
);

INSERT INTO students (name, deep_dive) VALUES
('Antoni', 'Cloud / DevOps'),
('Pedro', 'Cloud / DevOps'),
('Thunshan', 'Cloud / DevOps'),
('Mohamed', 'Cloud / DevOps');
```

### Validating the Database

That's all the generic confirguration we need to create a PostgreSQL DB. Before moving onto the MVC it's worth making sure it's behaving as we expect. 

1. Build the image: `docker build -t emilesherrott/students-db:0.0.1.RELEASE .`
2. Run a container: `docker run --name students-db -d emilesherrott/students-db:0.0.1.RELEASE`
  - We don't need to provide port details as we don't want to access to container using the browser
  - We also provide a name for the container: `students-db`
3. Enter to container: `docker exec -it students-db bash`
  - `docker exec`: allows us to run commands in an already running container
  - `-it`
    - `i` allows for us to interact with the container
    - `t` provides a terminal for the interaction
    - `students-db` the name of the container to enter
  - `bash` allows us run shell commands inside the container for further interaction
4. Now inside the container, run: `psql -U postgres -d students`
  - `psql` the **cli** for **postgreSQL**, we use it to interact with a **postgreSQL** db. 
  - `-U postgres` pass in information about the DB user / the default name of the user when creating a **postgreSQL db** is **postgres**
  - `-d students` referencing the database to connect to, called **students**
    - We named the database pokemon in the **Dockerfile**
5. `\dt`: shows all tables in the database. There should be one called **students**
6. `SELECT * FROM students;`: Check everything in the **students** table defined in the **students.sql** file. 

At this stage if we can see a response we're ok to progress to the **MVC**. 

## MVC Microservice 

The MVC microservice will be very similar to other MVC's you'll be familiar with. We'll need a:
- **Dockerfile** which contains the configuration to build the image
- **database/connect.js** which is a file inside a folder which contains the configuration to connect to the **db microservice**

### Dockerfile

In this Dockerfile, we'll build an image and also pass in the necessary **environment variables** to access the **db microservice**. 

Note: We can also use a **.env** file but centralised configuration may make it easier to place these inside the **Dockerfile**

```Dockerfile
FROM node:16
WORKDIR /app
COPY package*.json /app
RUN npm install
COPY . /app
ENV PORT=3000
# The default value of a user when creating a postgreSQL DB
ENV DB_USER=postgres
# The value of the service name which is used in the 'docker-compose.yml' file
ENV DB_HOST=students-db
# The name of the database we assigned in the 'students-db' microservice
ENV DB_NAME=students
# The value of the password we assigned in the 'students-db' microservice
ENV DB_PASSWORD=docker
# The default port when creating a postgreSQL DB
ENV DB_PORT=5432
EXPOSE 3000
CMD ["node", "index.js"]
```

### db/connect.js

Inside the MVC proper, we still need to connect to the database and export the `db` as usual. We don't need a **setup-db.js** or a **.sql** file as this is now handled through the **db microservice**.

```js
const { Pool } = require('pg');

const db = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT || 5432,
});

module.exports = db;
```

The **models** in the MVC can use this **database** as normal. 

Once complete we'll need to build the image: `docker build -t emilesherrott/students-mvc:0.0.1.RELEASE .`

## docker-compse

Now we have two **microservices / Docker Images** we can launch them together using a **docker-compose.yml** file. 

```yaml
version: '3.9'
services:
  students-mvc:
    image: emilesherrott/students-mvc:0.0.1.RELEASE
    ports:
      - "3000:3000"
    restart: always
    depends_on:
      - student-db
    networks:
      - student-network

  # The value of 'DB_HOST' we reference in the MVC Dockerfile  
  student-db:
    image: emilesherrott/student-db:0.0.1.RELEASE
    ports:
      - "5432:5432"
    restart: always
    networks:
      - student-network
      
networks:
  student-network:
```