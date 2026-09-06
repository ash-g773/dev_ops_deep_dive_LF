# Base Image used to build image
FROM postgres 
# Sets the DB password
ENV POSTGRES_PASSWORD docker
# Sets the DB name
ENV POSTGRES_DB countries
# Copies contents to 'students.sql' over to Image and DB entry point
COPY countries.sql /docker-entrypoint-initdb.d/