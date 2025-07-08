package org.springframework.samples.petclinic.integration;

import org.springframework.stereotype.Component;

@Component
public class QueueItSettings {

	// Hardcoded constants matching IntegrationConfigProvider pattern
	private static final String CUSTOMER_ID = "futuraforge";

	private static final String SECRET_KEY = "62cc5b6d-cad7-44c5-88a2-34fa78f73b767c7dcee7-5e81-44c4-93ea-0990c14f3176";

	private static final String API_KEY = "4607e3f0-dcb2-4714-9570-45d7e662c45f";

	public String getCustomerId() {
		return CUSTOMER_ID;
	}

	public String getSecretKey() {
		return SECRET_KEY;
	}

	public String getApiKey() {
		return API_KEY;
	}

	// Build base URL dynamically like IntegrationConfigProvider
	public String getBaseUrl() {
		return String.format("https://%s.queue-it.net", CUSTOMER_ID);
	}

}