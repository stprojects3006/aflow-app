package org.springframework.samples.petclinic.config;

import com.queue_it.connector.models.ConnectorSettings;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class QueueItConfig {

    // QueueIt configuration constants
    public static final String CUSTOMER_ID = "futuraforge";
    public static final String SECRET_KEY = "62cc5b6d-cad7-44c5-88a2-34fa78f73b767c7dcee7-5e81-44c4-93ea-0990c14f3176";
    public static final String API_KEY = "4607e3f0-dcb2-4714-9570-45d7e662c45f";
    public static final String QUEUEIT_TOKEN_KEY = "queueittoken";

    @Bean
    public ConnectorSettings connectorSettings() {
        ConnectorSettings settings = new ConnectorSettings();
        // Set any required properties if needed
        return settings;
    }
} 