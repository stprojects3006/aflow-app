package org.springframework.samples.petclinic.integration;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.client.RestTemplate;
import org.springframework.samples.petclinic.integration.QueueItSettings;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URL;
import java.net.URLConnection;

@Controller
@RequestMapping("/integration/queueit")
public class QueueItIntegrationController {

	private final RestTemplate restTemplate;

	private final MeterRegistry meterRegistry;

	private final QueueItSettings queueItSettings;

	// Hardcoded constants matching IntegrationConfigProvider pattern
	private static final String CUSTOMER_ID = "futuraforge";

	private static final String API_KEY = "4607e3f0-dcb2-4714-9570-45d7e662c45f";

	private static final int DOWNLOAD_TIMEOUT_MS = 4000;

	private static final int MAX_RETRY_COUNT = 5;

	public QueueItIntegrationController(RestTemplate restTemplate, MeterRegistry meterRegistry,
			QueueItSettings queueItSettings) {
		this.restTemplate = restTemplate;
		this.meterRegistry = meterRegistry;
		this.queueItSettings = queueItSettings;
	}

	// Helper to build headers for Queue-it API (aligned with IntegrationConfigProvider)
	private HttpHeaders buildHeaders() {
		HttpHeaders headers = new HttpHeaders();
		headers.set("api-key", API_KEY);
		return headers;
	}

	// Helper to construct base URL dynamically (aligned with IntegrationConfigProvider
	// pattern)
	private String buildBaseUrl() {
		return String.format("https://%s.queue-it.net", CUSTOMER_ID);
	}

	@GetMapping("")
	public String integrationTestingPage() {
		return "integrationTesting";
	}

	// Get integration configuration (aligned with IntegrationConfigProvider)
	@GetMapping("/config")
	@ResponseBody
	public ResponseEntity<String> getIntegrationConfig() {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_config_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "config").increment();

		try {
			// Use the same URL pattern as IntegrationConfigProvider
			String url = String.format("https://%s.queue-it.net/status/integrationconfig/secure/%s", CUSTOMER_ID,
					CUSTOMER_ID);
			System.out.println("[DEBUG] QueueIt API URL (config): " + url);

			// Use the same HTTP connection pattern as IntegrationConfigProvider
			String jsonText = getJsonText(url);

			// Record success metrics
			meterRegistry.counter("queueit_api_success_total", "operation", "config").increment();

			return ResponseEntity.ok(jsonText);
		}
		catch (Exception e) {
			System.out.println("[DEBUG] Exception in getIntegrationConfig: " + e.getMessage());
			e.printStackTrace();
			// Record error metrics
			meterRegistry
				.counter("queueit_api_errors_total", "operation", "config", "error_type", e.getClass().getSimpleName())
				.increment();
			throw e;
		}
		finally {
			sample.stop(Timer.builder("queueit_config_duration").tag("operation", "config").register(meterRegistry));
		}
	}

	// Helper method matching IntegrationConfigProvider.getJsonText()
	private String getJsonText(String url) {
		try {
			URL resource = new URL(url);
			URLConnection connection = resource.openConnection();
			connection.setRequestProperty("api-key", API_KEY);
			connection.setConnectTimeout(DOWNLOAD_TIMEOUT_MS);
			connection.setReadTimeout(DOWNLOAD_TIMEOUT_MS);

			BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()));
			StringBuilder response = new StringBuilder();
			String inputLine;
			while ((inputLine = in.readLine()) != null) {
				response.append(inputLine);
			}
			in.close();
			return response.toString();
		}
		catch (IOException e) {
			throw new RuntimeException("Failed to get JSON text from URL: " + url, e);
		}
	}

	/**
	 * Internal method to get integration configuration without HTTP response handling
	 * Used by QueueItIntegrationFilter
	 */
	public String getIntegrationConfigurationInternal() {
		try {
			// Use the same URL pattern as IntegrationConfigProvider
			String url = String.format("https://%s.queue-it.net/status/integrationconfig/secure/%s", CUSTOMER_ID,
					CUSTOMER_ID);
			System.out.println("[DEBUG] QueueIt API URL (internal config): " + url);
			return getJsonText(url);
		}
		catch (Exception e) {
			System.out.println("[DEBUG] Exception in getIntegrationConfigurationInternal: " + e.getMessage());
			e.printStackTrace();
			return null;
		}
	}

	// Health check endpoint using IntegrationConfigProvider pattern
	@GetMapping("/health")
	@ResponseBody
	public ResponseEntity<String> healthCheck() {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_health_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "health").increment();

		try {
			// Use the same base URL pattern as IntegrationConfigProvider
			String url = String.format("https://%s.queue-it.net/health", CUSTOMER_ID);
			System.out.println("[DEBUG] QueueIt API URL (health): " + url);

			// Use the same HTTP connection pattern as IntegrationConfigProvider
			String response = getJsonText(url);

			// Record success metrics
			meterRegistry.counter("queueit_api_success_total", "operation", "health").increment();

			return ResponseEntity.ok(response);
		}
		catch (Exception e) {
			System.out.println("[DEBUG] Exception in healthCheck: " + e.getMessage());
			e.printStackTrace();
			// Record error metrics
			meterRegistry
				.counter("queueit_api_errors_total", "operation", "health", "error_type", e.getClass().getSimpleName())
				.increment();
			throw e;
		}
		finally {
			sample.stop(Timer.builder("queueit_health_duration").tag("operation", "health").register(meterRegistry));
		}
	}

	// Queue endpoint using IntegrationConfigProvider pattern
	@GetMapping("/queue")
	@ResponseBody
	public ResponseEntity<String> getQueueStatus() {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_queue_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "queue").increment();

		try {
			// Use the same base URL pattern as IntegrationConfigProvider
			String url = String.format("https://%s.queue-it.net/status/queue", CUSTOMER_ID);
			System.out.println("[DEBUG] QueueIt API URL (queue): " + url);

			// Use the same HTTP connection pattern as IntegrationConfigProvider
			String response = getJsonText(url);

			// Record success metrics
			meterRegistry.counter("queueit_api_success_total", "operation", "queue").increment();

			return ResponseEntity.ok(response);
		}
		catch (Exception e) {
			System.out.println("[DEBUG] Exception in getQueueStatus: " + e.getMessage());
			e.printStackTrace();
			// Record error metrics
			meterRegistry
				.counter("queueit_api_errors_total", "operation", "queue", "error_type", e.getClass().getSimpleName())
				.increment();
			throw e;
		}
		finally {
			sample.stop(Timer.builder("queueit_queue_duration").tag("operation", "queue").register(meterRegistry));
		}
	}

	// UI form renderers for integration test cases (except /queue)
	@GetMapping("/validate")
	public String showValidatePage() {
		return "integration/queueit/validate";
	}

	@GetMapping("/cancel")
	public String showCancelPage() {
		return "integration/queueit/cancel";
	}

	@GetMapping("/extend-cookie")
	public String showExtendCookiePage() {
		return "integration/queueit/extend-cookie";
	}

	@GetMapping("/status")
	public String showStatusPage() {
		return "integration/queueit/status";
	}

	@GetMapping("/health-ui")
	public String showHealthPage() {
		return "integration/queueit/health";
	}

	@GetMapping("/session-info")
	public String showSessionInfoPage() {
		return "integration/queueit/session-info";
	}

	@GetMapping("/reset-test-state")
	public String showResetTestStatePage() {
		return "integration/queueit/reset-test-state";
	}

	@GetMapping("/run-junit")
	public String showRunJunitPage() {
		return "integration/queueit/run-junit";
	}

	@GetMapping("/simulate-event")
	public String showSimulateEventPage() {
		return "integration/queueit/simulate-event";
	}

	// POST handlers for form submissions (call actual Queue-it APIs)
	@PostMapping("/validate")
	public String handleValidate(@RequestParam("token") String token, Model model) {
		String body = "{\"token\":\"" + token + "\"}";
		ResponseEntity<String> response = validateQueueToken(body);
		model.addAttribute("response", response.getBody());
		return "integration/queueit/validate";
	}

	@PostMapping("/cancel")
	public String handleCancel(@RequestParam("sessionId") String sessionId, Model model) {
		String body = "{\"sessionId\":\"" + sessionId + "\"}";
		ResponseEntity<String> response = cancelQueueSession(body);
		model.addAttribute("response", response.getBody());
		return "integration/queueit/cancel";
	}

	@PostMapping("/extend-cookie")
	public String handleExtendCookie(@RequestParam("sessionId") String sessionId, Model model) {
		String body = "{\"sessionId\":\"" + sessionId + "\"}";
		ResponseEntity<String> response = extendQueueCookie(body);
		model.addAttribute("response", response.getBody());
		return "integration/queueit/extend-cookie";
	}

	@PostMapping("/status")
	public String handleStatus(Model model) {
		ResponseEntity<String> response = getQueueStatusStub();
		model.addAttribute("response", response.getBody());
		return "integration/queueit/status";
	}

	@PostMapping("/health")
	public String handleHealth(Model model) {
		ResponseEntity<String> response = healthCheck();
		model.addAttribute("response", response.getBody());
		return "integration/queueit/health";
	}

	@PostMapping("/reset-test-state")
	public String handleResetTestState(Model model) {
		ResponseEntity<String> response = resetTestState();
		model.addAttribute("response", response.getBody());
		return "integration/queueit/reset-test-state";
	}

	@PostMapping("/run-junit")
	public String handleRunJunit(Model model) {
		ResponseEntity<String> response = runJunit();
		model.addAttribute("response", response.getBody());
		return "integration/queueit/run-junit";
	}

	@PostMapping("/session-info")
	public String handleSessionInfo(Model model) {
		model.addAttribute("response", "{\"error\":\"Queue-it endpoint not implemented\"}");
		return "integration/queueit/session-info";
	}

	@PostMapping("/simulate-event")
	public String handleSimulateEvent(Model model) {
		model.addAttribute("response", "{\"error\":\"Queue-it endpoint not implemented\"}");
		return "integration/queueit/simulate-event";
	}

	@PostMapping("/queue")
	public String handleQueue(@RequestParam("userId") String userId, Model model) {
		// Simulate queueing a user (call Queue-it API or stub)
		String body = "{\"userId\":\"" + userId + "\"}";
		String responseText;
		boolean success = false;
		try {
			String url = queueItSettings.getBaseUrl() + "/queue";
			HttpHeaders headers = buildHeaders();
			headers.set("customer-id", queueItSettings.getCustomerId());
			headers.set("secret-key", queueItSettings.getSecretKey());
			headers.set("Content-Type", "application/json");
			HttpEntity<String> entity = new HttpEntity<>(body, headers);
			ResponseEntity<String> response = restTemplate.postForEntity(url, entity, String.class);
			responseText = response.getBody();
			success = response.getStatusCode().is2xxSuccessful();
		}
		catch (Exception e) {
			responseText = "{\"error\":\"Queue-it API error: " + e.getMessage() + "\"}";
		}
		model.addAttribute("response", responseText);
		model.addAttribute("showOverlay", success); // Show overlay only if queueing
													// succeeded
		return "integration/queueit/queue";
	}

	// Internal API methods for form POST handlers
	public ResponseEntity<String> validateQueueToken(String body) {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_validate_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "validate").increment();
		try {
			String url = queueItSettings.getBaseUrl() + "/validate";
			HttpHeaders headers = buildHeaders();
			headers.set("customer-id", queueItSettings.getCustomerId());
			headers.set("secret-key", queueItSettings.getSecretKey());
			headers.set("Content-Type", "application/json");
			HttpEntity<String> entity = new HttpEntity<>(body, headers);
			ResponseEntity<String> response = restTemplate.postForEntity(url, entity, String.class);
			meterRegistry.counter("queueit_api_success_total", "operation", "validate").increment();
			return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
		}
		catch (Exception e) {
			meterRegistry
				.counter("queueit_api_errors_total", "operation", "validate", "error_type",
						e.getClass().getSimpleName())
				.increment();
			return ResponseEntity.status(502).body("{\"error\":\"Queue-it API error: " + e.getMessage() + "\"}");
		}
		finally {
			sample
				.stop(Timer.builder("queueit_validate_duration").tag("operation", "validate").register(meterRegistry));
		}
	}

	public ResponseEntity<String> cancelQueueSession(String body) {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_cancel_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "cancel").increment();
		try {
			String url = queueItSettings.getBaseUrl() + "/cancel";
			HttpHeaders headers = buildHeaders();
			headers.set("customer-id", queueItSettings.getCustomerId());
			headers.set("secret-key", queueItSettings.getSecretKey());
			headers.set("Content-Type", "application/json");
			HttpEntity<String> entity = new HttpEntity<>(body, headers);
			ResponseEntity<String> response = restTemplate.postForEntity(url, entity, String.class);
			meterRegistry.counter("queueit_api_success_total", "operation", "cancel").increment();
			return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
		}
		catch (Exception e) {
			meterRegistry
				.counter("queueit_api_errors_total", "operation", "cancel", "error_type", e.getClass().getSimpleName())
				.increment();
			return ResponseEntity.status(502).body("{\"error\":\"Queue-it API error: " + e.getMessage() + "\"}");
		}
		finally {
			sample.stop(Timer.builder("queueit_cancel_duration").tag("operation", "cancel").register(meterRegistry));
		}
	}

	public ResponseEntity<String> extendQueueCookie(String body) {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_extend_cookie_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "extend-cookie").increment();
		try {
			String url = queueItSettings.getBaseUrl() + "/extend-cookie";
			HttpHeaders headers = buildHeaders();
			headers.set("customer-id", queueItSettings.getCustomerId());
			headers.set("secret-key", queueItSettings.getSecretKey());
			headers.set("Content-Type", "application/json");
			HttpEntity<String> entity = new HttpEntity<>(body, headers);
			ResponseEntity<String> response = restTemplate.postForEntity(url, entity, String.class);
			meterRegistry.counter("queueit_api_success_total", "operation", "extend-cookie").increment();
			return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
		}
		catch (Exception e) {
			meterRegistry
				.counter("queueit_api_errors_total", "operation", "extend-cookie", "error_type",
						e.getClass().getSimpleName())
				.increment();
			return ResponseEntity.status(502).body("{\"error\":\"Queue-it API error: " + e.getMessage() + "\"}");
		}
		finally {
			sample.stop(Timer.builder("queueit_extend_cookie_duration")
				.tag("operation", "extend-cookie")
				.register(meterRegistry));
		}
	}

	public ResponseEntity<String> getQueueStatusStub() {
		Timer.Sample sample = Timer.start(meterRegistry);
		meterRegistry.counter("queueit_status_total").increment();
		meterRegistry.counter("queueit_api_requests_total", "operation", "status").increment();
		try {
			String url = queueItSettings.getBaseUrl() + "/status";
			HttpHeaders headers = buildHeaders();
			headers.set("customer-id", queueItSettings.getCustomerId());
			headers.set("secret-key", queueItSettings.getSecretKey());
			headers.set("Content-Type", "application/json");
			HttpEntity<String> entity = new HttpEntity<>(headers);
			ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.GET, entity, String.class);
			meterRegistry.counter("queueit_api_success_total", "operation", "status").increment();
			return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
		}
		catch (Exception e) {
			meterRegistry
				.counter("queueit_api_errors_total", "operation", "status", "error_type", e.getClass().getSimpleName())
				.increment();
			return ResponseEntity.status(502).body("{\"error\":\"Queue-it API error: " + e.getMessage() + "\"}");
		}
		finally {
			sample.stop(Timer.builder("queueit_status_duration").tag("operation", "status").register(meterRegistry));
		}
	}

	public ResponseEntity<String> resetTestState() {
		meterRegistry.counter("queueit_reset_test_state_total").increment();
		return ResponseEntity.status(501).body("{\"error\":\"Queue-it endpoint not implemented\"}");
	}

	public ResponseEntity<String> runJunit() {
		meterRegistry.counter("queueit_run_junit_total").increment();
		return ResponseEntity.ok("{\"result\":\"JUnit tests run (stub)\"}");
	}

}