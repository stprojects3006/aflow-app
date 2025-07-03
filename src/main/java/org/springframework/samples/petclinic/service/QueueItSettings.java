package org.springframework.samples.petclinic.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class QueueItSettings {

	@Value("${queueit.api.customer-id:futuraforge}")
	private String customerId;

	@Value("${queueit.api.secret-key:62cc5b6d-cad7-44c5-88a2-34fa78f73b767c7dcee7-5e81-44c4-93ea-0990c14f3176}")
	private String secretKey;

	@Value("${queueit.api.api-key:4607e3f0-dcb2-4714-9570-45d7e662c45f}")
	private String apiKey;

	@Value("${queueit.api.base-url:https://api.queue-it.net}")
	private String baseUrl;

	public String getCustomerId() {
		return customerId;
	}

	public String getSecretKey() {
		return secretKey;
	}

	public String getApiKey() {
		return apiKey;
	}

	public String getBaseUrl() {
		return baseUrl;
	}

}