FROM eclipse-temurin:17-jre-jammy

ARG JAR_FILE=target/*.jar
WORKDIR /app
COPY ${JAR_FILE} app.jar
EXPOSE 8085

# Add a small healthcheck that returns non-zero when /health is not OK
HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8085/health || exit 1

ENTRYPOINT ["java","-jar","/app/app.jar"]
