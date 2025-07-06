package org.springframework.samples.petclinic.integration;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
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
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_validate_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "validate").increment();
		
		try {
			String url = queueItSettings.getBaseUrl() + "/validate";
			HttpHeaders headers = buildHeaders();
			String body = String.format("{\"token\":\"%s\"}", token);
			HttpEntity<String> entity = new HttpEntity<>(body, headers);
			ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
			
			// Record success metrics
			meterRegistry.counter("queueit_api_success_total", "operation", "validate").increment();
			meterRegistry.gauge("queueit_api_response_time_seconds", 
				Timer.builder("queueit_validate_duration")
					.tag("operation", "validate")
					.register(meterRegistry));
			
			return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
		} catch (Exception e) {
			// Record error metrics
			meterRegistry.counter("queueit_api_errors_total", "operation", "validate", "error_type", e.getClass().getSimpleName()).increment();
			throw e;
		} finally {
			sample.stop(Timer.builder("queueit_validate_duration")
				.tag("operation", "validate")
				.register(meterRegistry));
		}
	}

	@PostMapping("/queue")
	@ResponseBody
	public ResponseEntity<String> simulateQueueUser(@RequestParam String userId) {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_queue_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "queue").increment();
		
		try {
			String url = queueItSettings.getBaseUrl() + "/queue";
			HttpHeaders headers = buildHeaders();
			String body = String.format("{\"userId\":\"%s\"}", userId);
			HttpEntity<String> entity = new HttpEntity<>(body, headers);
			ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
			
			// Record success metrics
			meterRegistry.counter("queueit_api_success_total", "operation", "queue").increment();
			
			return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
		} catch (Exception e) {
			// Record error metrics
			meterRegistry.counter("queueit_api_errors_total", "operation", "queue", "error_type", e.getClass().getSimpleName()).increment();
			throw e;
		} finally {
			sample.stop(Timer.builder("queueit_queue_duration")
				.tag("operation", "queue")
				.register(meterRegistry));
		}
	}

	@PostMapping("/cancel")
	@ResponseBody
	public ResponseEntity<String> cancelQueueSession(@RequestParam String sessionId) {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_cancel_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "cancel").increment();
		
		try {
			String url = queueItSettings.getBaseUrl() + "/cancel";
			HttpHeaders headers = buildHeaders();
			String body = String.format("{\"sessionId\":\"%s\"}", sessionId);
			HttpEntity<String> entity = new HttpEntity<>(body, headers);
			ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
			
			// Record success metrics
			meterRegistry.counter("queueit_api_success_total", "operation", "cancel").increment();
			
			return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
		} catch (Exception e) {
			// Record error metrics
			meterRegistry.counter("queueit_api_errors_total", "operation", "cancel", "error_type", e.getClass().getSimpleName()).increment();
			throw e;
		} finally {
			sample.stop(Timer.builder("queueit_cancel_duration")
				.tag("operation", "cancel")
				.register(meterRegistry));
		}
	}

	@PostMapping("/extend-cookie")
	@ResponseBody
	public ResponseEntity<String> extendQueueCookie(@RequestParam String sessionId) {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_extend_cookie_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "extend_cookie").increment();
		
		try {
			String url = queueItSettings.getBaseUrl() + "/extend-cookie";
			HttpHeaders headers = buildHeaders();
			String body = String.format("{\"sessionId\":\"%s\"}", sessionId);
			HttpEntity<String> entity = new HttpEntity<>(body, headers);
			ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
			
			// Record success metrics
			meterRegistry.counter("queueit_api_success_total", "operation", "extend_cookie").increment();
			
			return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
		} catch (Exception e) {
			// Record error metrics
			meterRegistry.counter("queueit_api_errors_total", "operation", "extend_cookie", "error_type", e.getClass().getSimpleName()).increment();
			throw e;
		} finally {
			sample.stop(Timer.builder("queueit_extend_cookie_duration")
				.tag("operation", "extend_cookie")
				.register(meterRegistry));
		}
	}

	@GetMapping("/status")
	@ResponseBody
	public ResponseEntity<String> getQueueStatus() {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_status_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "status").increment();
		
		try {
			String url = queueItSettings.getBaseUrl() + "/status";
			HttpHeaders headers = buildHeaders();
			HttpEntity<Void> entity = new HttpEntity<>(headers);
			ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.GET, entity, String.class);
			
			// Record success metrics
			meterRegistry.counter("queueit_api_success_total", "operation", "status").increment();
			
			return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
		} catch (Exception e) {
			// Record error metrics
			meterRegistry.counter("queueit_api_errors_total", "operation", "status", "error_type", e.getClass().getSimpleName()).increment();
			throw e;
		} finally {
			sample.stop(Timer.builder("queueit_status_duration")
				.tag("operation", "status")
				.register(meterRegistry));
		}
	}

	@GetMapping("/health")
	@ResponseBody
	public ResponseEntity<String> healthCheck() {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_health_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "health").increment();
		
		try {
			String url = queueItSettings.getBaseUrl() + "/health";
			HttpHeaders headers = buildHeaders();
			HttpEntity<Void> entity = new HttpEntity<>(headers);
			ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.GET, entity, String.class);
			
			// Record success metrics
			meterRegistry.counter("queueit_api_success_total", "operation", "health").increment();
			
			return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
		} catch (Exception e) {
			// Record error metrics
			meterRegistry.counter("queueit_api_errors_total", "operation", "health", "error_type", e.getClass().getSimpleName()).increment();
			throw e;
		} finally {
			sample.stop(Timer.builder("queueit_health_duration")
				.tag("operation", "health")
				.register(meterRegistry));
		}
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