FROM tomcat:latest
ARG VERSION
COPY myweb-${VERSION}.war /usr/local/tomcat/webapps/myweb.war
