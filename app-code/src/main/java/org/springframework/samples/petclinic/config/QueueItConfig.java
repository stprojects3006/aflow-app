package org.springframework.samples.petclinic.config;

import com.queue_it.connector.models.ConnectorSettings;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.samples.petclinic.integration.QueueItSettings;

@Configuration
public class QueueItConfig {

	@Autowired
	private QueueItSettings queueItSettings;

	public static final String QUEUEIT_TOKEN_KEY = "queueittoken";

	@Bean
	public ConnectorSettings connectorSettings() {
		return new ConnectorSettings(queueItSettings.getCustomerId(), queueItSettings.getSecretKey(),
				queueItSettings.getApiKey());
	}

}