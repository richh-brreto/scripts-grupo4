FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=boost

COPY db.sql /docker-entrypoint-initdb.d/db.sql
