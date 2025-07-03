package org.springframework.samples.petclinic.integration;

import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
import org.springframework.samples.petclinic.service.QueueItSettings;

@Controller
@RequestMapping("/integration/queueit")
public class QueueItIntegrationController {

	private final RestTemplate restTemplate;

	private final MeterRegistry meterRegistry;

	private final QueueItSettings queueItSettings;

	public QueueItIntegrationController(RestTemplate restTemplate, MeterRegistry meterRegistry,
			QueueItSettings queueItSettings) {
		this.restTemplate = restTemplate;
		this.meterRegistry = meterRegistry;
		this.queueItSettings = queueItSettings;
	}

	// Helper to build headers for Queue-it API
	private HttpHeaders buildHeaders() {
		HttpHeaders headers = new HttpHeaders();
		headers.setContentType(MediaType.APPLICATION_JSON);
		headers.set("api-key", queueItSettings.getApiKey());
		headers.set("customer-id", queueItSettings.getCustomerId());
		headers.set("secret-key", queueItSettings.getSecretKey());
		return headers;
	}

	@GetMapping("")
	public String integrationTestingPage() {
		return "integrationTesting";
	}

	@PostMapping("/validate")
	@ResponseBody
	public ResponseEntity<String> validateQueueToken(@RequestParam String token) {
		meterRegistry.counter("queueit_validate_total").increment();
		String url = queueItSettings.getBaseUrl() + "/validate";
		HttpHeaders headers = buildHeaders();
		String body = String.format("{\"token\":\"%s\"}", token);
		HttpEntity<String> entity = new HttpEntity<>(body, headers);
		ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
		return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
	}

	@PostMapping("/queue")
	@ResponseBody
	public ResponseEntity<String> simulateQueueUser(@RequestParam String userId) {
		meterRegistry.counter("queueit_queue_total").increment();
		String url = queueItSettings.getBaseUrl() + "/queue";
		HttpHeaders headers = buildHeaders();
		String body = String.format("{\"userId\":\"%s\"}", userId);
		HttpEntity<String> entity = new HttpEntity<>(body, headers);
		ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
		return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
	}

	@PostMapping("/cancel")
	@ResponseBody
	public ResponseEntity<String> cancelQueueSession(@RequestParam String sessionId) {
		meterRegistry.counter("queueit_cancel_total").increment();
		String url = queueItSettings.getBaseUrl() + "/cancel";
		HttpHeaders headers = buildHeaders();
		String body = String.format("{\"sessionId\":\"%s\"}", sessionId);
		HttpEntity<String> entity = new HttpEntity<>(body, headers);
		ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
		return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
	}

	@PostMapping("/extend-cookie")
	@ResponseBody
	public ResponseEntity<String> extendQueueCookie(@RequestParam String sessionId) {
		meterRegistry.counter("queueit_extend_cookie_total").increment();
		String url = queueItSettings.getBaseUrl() + "/extend-cookie";
		HttpHeaders headers = buildHeaders();
		String body = String.format("{\"sessionId\":\"%s\"}", sessionId);
		HttpEntity<String> entity = new HttpEntity<>(body, headers);
		ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
		return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
	}

	@GetMapping("/status")
	@ResponseBody
	public ResponseEntity<String> getQueueStatus() {
		meterRegistry.counter("queueit_status_total").increment();
		String url = queueItSettings.getBaseUrl() + "/status";
		HttpHeaders headers = buildHeaders();
		HttpEntity<Void> entity = new HttpEntity<>(headers);
		ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.GET, entity, String.class);
		return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
	}

	@GetMapping("/health")
	@ResponseBody
	public ResponseEntity<String> healthCheck() {
		meterRegistry.counter("queueit_health_total").increment();
		String url = queueItSettings.getBaseUrl() + "/health";
		HttpHeaders headers = buildHeaders();
		HttpEntity<Void> entity = new HttpEntity<>(headers);
		ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.GET, entity, String.class);
		return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
	}

	@PostMapping("/simulate-event")
	@ResponseBody
	public ResponseEntity<String> simulateEvent() {
		meterRegistry.counter("queueit_simulate_event_total").increment();
		return ResponseEntity.status(501).body("Not Implemented");
	}

	@GetMapping("/session-info")
	@ResponseBody
	public ResponseEntity<String> inspectSessionInfo() {
		meterRegistry.counter("queueit_session_info_total").increment();
		return ResponseEntity.status(501).body("Not Implemented");
	}

	@PostMapping("/reset-test-state")
	@ResponseBody
	public ResponseEntity<String> resetTestState() {
		meterRegistry.counter("queueit_reset_test_state_total").increment();
		return ResponseEntity.status(501).body("Not Implemented");
	}

}