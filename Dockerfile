# Use a small JRE base
FROM eclipse-temurin:17-jre-jammy

ARG JAR_FILE=target/*.jar
WORKDIR /app
COPY ${JAR_FILE} app.jar
EXPOSE 8085
ENTRYPOINT ["java","-jar","/app/app.jar"]
