# ---- Build stage: compile & package WAR ----
FROM maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /app

# Cache dependencies to speed up builds
COPY pom.xml .
RUN mvn -B -q -DskipTests dependency:go-offline

# Add the source and build
COPY src ./src
RUN mvn -B -DskipTests clean package

# ---- Runtime stage: Tomcat 9 for javax.* WARs ----
FROM tomcat:9.0-jdk17
# Optional: remove default webapps to keep image clean
RUN rm -rf /usr/local/tomcat/webapps/*

# If your WAR name differs, adjust the filename accordingly
COPY --from=build /app/target/hello-world-war-1.0.0.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080

