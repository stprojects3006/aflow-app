# Start from a lightweight OpenJDK image
FROM eclipse-temurin:17-jdk-alpine

# Set the working directory
WORKDIR /app

# Copy the built jar into the image
COPY jars/pet-clinkc.jar app.jar

# Expose the default port
EXPOSE 8080

# Run the application with the MySQL profile
ENTRYPOINT ["java", "-jar", "app.jar", "--spring.profiles.active=mysql"] 