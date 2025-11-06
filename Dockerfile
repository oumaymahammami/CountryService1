# Image Java 21
FROM eclipse-temurin:21-jdk

WORKDIR /app

# Copier le JAR avec le BON NOM
COPY target/countryService-0.0.1-SNAPSHOT.jar app.jar

# ⚠️ CORRECTION : Exposer le port 8082 (pas 8080)
EXPOSE 8082

# Commande pour démarrer
ENTRYPOINT ["java", "-jar", "/app.jar"]
