FROM tomcat:10-jdk17
COPY target/*.war /usr/local/tomcat/webapps/hello-world-war.war
EXPOSE 8080
