FROM maven:3.8.2-openjdk-8 as mavenbuilder
ARG TEST=/var/lib/
WORKDIR ${TEST}
COPY . .
RUN mvn clean package

FROM tomcat:10.1-jdk21
ARG TEST=/var/lib
COPY --from=mavenbuilder ${TEST}/target/hello-world-war-1.0.0.war /usr/local/tomcat/webapps
