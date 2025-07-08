package org.springframework.samples.petclinic.integration;

import io.micrometer.core.instrument.MeterRegistry;
import jakarta.servlet.*;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.samples.petclinic.integration.QueueItSettings;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.util.regex.Pattern;

/**
 * Queue-it Integration Filter that provides full queue management capabilities Similar to
 * qFilter but integrated with QueueItIntegrationController pattern
 */
@WebFilter("/*")
public class QueueItIntegrationFilter implements Filter {

	private static final Logger logger = LoggerFactory.getLogger(QueueItIntegrationFilter.class);

	// Hardcoded constants matching IntegrationConfigProvider pattern
	private static final String CUSTOMER_ID = "futuraforge";

	private static final String SECRET_KEY = "62cc5b6d-cad7-44c5-88a2-34fa78f73b767c7dcee7-5e81-44c4-93ea-0990c14f3176";

	private static final String API_KEY = "4607e3f0-dcb2-4714-9570-45d7e662c45f";

	private static final String QUEUEIT_TOKEN_KEY = "queueittoken";

	private QueueItSettings queueItSettings;

	private MeterRegistry meterRegistry;

	// Temporarily remove dependency on QueueItIntegrationController to avoid circular
	// dependency
	// private QueueItIntegrationController integrationController;

	@Autowired
	public void setQueueItSettings(QueueItSettings queueItSettings) {
		this.queueItSettings = queueItSettings;
	}

	@Autowired
	public void setMeterRegistry(MeterRegistry meterRegistry) {
		this.meterRegistry = meterRegistry;
	}

	// Temporarily comment out to avoid circular dependency
	/*
	 * @Autowired public void setIntegrationController(QueueItIntegrationController
	 * integrationController) { this.integrationController = integrationController; }
	 */

	@Override
	public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
			throws IOException, ServletException {

		logger.info("QueueIt Integration Filter: Processing request");

		// Increment total requests metric
		if (meterRegistry != null) {
			meterRegistry.counter("queueit_integration_filter_requests_total").increment();
		}

		// Call the validation function before the rest of the filter chain is processed
		boolean proceed = doValidation((HttpServletRequest) request, (HttpServletResponse) response);

		// Passes the request along the filter chain
		if (proceed && !response.isCommitted()) {
			if (meterRegistry != null) {
				meterRegistry.counter("queueit_integration_filter_proceed_total").increment();
			}
			chain.doFilter((HttpServletRequest) request, (HttpServletResponse) response);
		}
		else {
			if (meterRegistry != null) {
				meterRegistry.counter("queueit_integration_filter_blocked_total").increment();
			}
		}
	}

	private boolean doValidation(HttpServletRequest request, HttpServletResponse response) {
		try {
			logger.debug("[QueueItFilter] Incoming requestURI: {}", request.getRequestURI());

			// Skip validation for integration endpoints to avoid infinite loops
			String requestURI = request.getRequestURI();
			if (requestURI.startsWith("/integration/queueit") || requestURI.startsWith("/actuator")
					|| requestURI.startsWith("/error")) {
				logger.debug("Skipping validation for integration endpoint: {}", requestURI);
				return true;
			}

			// Remove or bypass isPublicRoute logic so all other routes are protected
			if (isPublicRoute(requestURI)) {
				logger.debug("[QueueItFilter] Public route, skipping validation: {}", requestURI);
				return true;
			}

			// Get the pure URL (without queue token)
			String pureUrl = getPureUrl(request);
			logger.debug("[QueueIt] pureUrl: {} | requestURL: {}", pureUrl, request.getRequestURL().toString());

			// Extract queue token from query string
			String queueitToken = getParameterFromQueryString(request, QUEUEIT_TOKEN_KEY);
			logger.debug("Queue token: {}", queueitToken != null && !queueitToken.isEmpty() ? "present" : "absent");

			// Get integration configuration using the controller pattern
			String integrationConfig = getIntegrationConfiguration();
			if (integrationConfig == null) {
				logger.warn("Failed to get integration configuration, allowing request to proceed");
				return true;
			}

			// Validate the request
			QueueValidationResult validationResult = validateQueueRequest(pureUrl, queueitToken, integrationConfig);

			if (validationResult.requiresRedirect()) {
				// Record redirect metrics
				if (meterRegistry != null) {
					meterRegistry
						.counter("queueit_integration_redirects_total", "action_type", validationResult.getActionType(),
								"is_ajax", String.valueOf(validationResult.isAjaxRequest()))
						.increment();
				}

				if (validationResult.isAjaxRequest()) {
					// Handle AJAX redirect
					handleAjaxRedirect(response, validationResult);
				}
				else {
					// Handle HTTP redirect
					handleHttpRedirect(response, validationResult);
				}
				return false;
			}
			else {
				// Record successful validation metrics
				if (meterRegistry != null) {
					meterRegistry
						.counter("queueit_integration_validations_success_total", "action_type",
								validationResult.getActionType())
						.increment();
				}

				// Remove queue token from URL if present and current URL contains the
				// token
				if (queueitToken != null && !queueitToken.isEmpty() && "Queue".equals(validationResult.getActionType())
						&& pureUrl != null && !pureUrl.equals(request.getRequestURL().toString()
								+ (request.getQueryString() != null ? ("?" + request.getQueryString()) : ""))) {
					response.sendRedirect(pureUrl);
					response.getOutputStream().flush();
					response.getOutputStream().close();
					if (meterRegistry != null) {
						meterRegistry.counter("queueit_integration_token_removal_redirects_total").increment();
					}
					return false;
				}
				// Otherwise, let the request proceed
				// If this is /owners/new and user just cleared the queue, set overlay
				// flag
				if (requestURI.equals("/owners/new")) {
					HttpSession session = request.getSession();
					session.setAttribute("showOverlay", true);
				}
			}
		}
		catch (Exception ex) {
			logger.error("Error in queue validation", ex);
			if (meterRegistry != null) {
				meterRegistry
					.counter("queueit_integration_validation_errors_total", "error_type", ex.getClass().getSimpleName())
					.increment();
			}
		}
		return true;
	}

	private String getIntegrationConfiguration() {
		try {
			// Implement the configuration retrieval directly in the filter
			// This avoids the circular dependency with QueueItIntegrationController
			String url = String.format("https://%s.queue-it.net/status/integrationconfig/secure/%s", CUSTOMER_ID,
					CUSTOMER_ID);
			logger.debug("QueueIt API URL (filter config): " + url);
			return getJsonText(url);
		}
		catch (Exception e) {
			logger.error("Failed to get integration configuration", e);
			return null;
		}
	}

	private QueueValidationResult validateQueueRequest(String pureUrl, String queueitToken, String integrationConfig) {
		// Simplified validation logic - in a real implementation, you would use
		// Queue-it's KnownUser.validateRequestByIntegrationConfig
		QueueValidationResult result = new QueueValidationResult();

		// Check if token is present and valid
		if (queueitToken == null || queueitToken.isEmpty()) {
			// No token - redirect to queue
			result.setRequiresRedirect(true);
			result.setActionType("Queue");
			result.setRedirectUrl(buildQueueUrl(pureUrl));
			return result;
		}

		// Validate token (simplified - in real implementation, use Queue-it's validation)
		if (!isValidToken(queueitToken)) {
			// Invalid token - redirect to queue
			result.setRequiresRedirect(true);
			result.setActionType("Queue");
			result.setRedirectUrl(buildQueueUrl(pureUrl));
			return result;
		}

		// Token is valid - allow request to proceed
		result.setRequiresRedirect(false);
		result.setActionType("Queue");
		return result;
	}

	private boolean isValidToken(String token) {
		// Simplified token validation - in real implementation, use Queue-it's
		// KnownUser.validateRequestByIntegrationConfig
		// For now, just check if token is not empty and has a reasonable format
		return token != null && !token.isEmpty() && token.length() > 10;
	}

	private String buildQueueUrl(String targetUrl) {
		// Build queue URL using the same pattern as IntegrationConfigProvider
		return String.format("https://%s.queue-it.net/queue?targetUrl=%s", CUSTOMER_ID, targetUrl);
	}

	private void handleAjaxRedirect(HttpServletResponse response, QueueValidationResult validationResult) {
		// Adding no cache headers to prevent browsers to cache requests
		response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate, max-age=0");
		response.setHeader("Pragma", "no-cache");
		response.setHeader("Expires", "Fri, 01 Jan 1990 00:00:00 GMT");

		// Set custom queue redirect header
		response.setHeader("X-Queue-It-Redirect", validationResult.getRedirectUrl());
		response.setHeader("Access-Control-Expose-Headers", "X-Queue-It-Redirect");

		if (meterRegistry != null) {
			meterRegistry.counter("queueit_integration_ajax_redirects_total").increment();
		}
	}

	private void handleHttpRedirect(HttpServletResponse response, QueueValidationResult validationResult)
			throws IOException {
		// Send the user to the queue
		response.sendRedirect(validationResult.getRedirectUrl());
		if (meterRegistry != null) {
			meterRegistry.counter("queueit_integration_http_redirects_total").increment();
		}
	}

	private String getPureUrl(HttpServletRequest request) {
		String scheme = request.getScheme();
		String hostHeader = request.getHeader("Host");
		String uri = request.getRequestURI();
		String queryString = request.getQueryString();

		StringBuilder url = new StringBuilder();
		url.append(scheme).append("://").append(hostHeader).append(uri);
		if (queryString != null && !queryString.isEmpty()) {
			url.append("?").append(queryString);
		}
		// Remove queueittoken param if present (existing logic)
		Pattern pattern = Pattern.compile("([\\?&])(" + QUEUEIT_TOKEN_KEY + "=[^&]*)", Pattern.CASE_INSENSITIVE);
		String pureUrl = pattern.matcher(url.toString()).replaceAll("");
		return pureUrl;
	}

	private String getParameterFromQueryString(HttpServletRequest request, String key) {
		String queryString = request.getQueryString();
		if (key == null || key.isEmpty() || queryString == null || queryString.isEmpty()) {
			return "";
		}

		String[] params = queryString.split("&");
		for (String param : params) {
			String[] paramParts = param.split("=");
			if (paramParts.length >= 2 && paramParts[0].equals(key)) {
				return paramParts[1];
			}
		}
		return "";
	}

	private boolean isPublicRoute(String requestURI) {
		// Only protect specific routes - everything else is public
		String[] protectedRoutes = { "/owners/new", // Add New Owner page
				"/integration/queueit" // Integration testing routes
		};

		for (String route : protectedRoutes) {
			if (requestURI.equals(route) || requestURI.startsWith(route)) {
				return false; // This route needs protection
			}
		}

		// Everything else is public
		return true;
	}

	@Override
	public void init(FilterConfig filterConfig) throws ServletException {
		logger.info("QueueIt Integration Filter initialized");
	}

	@Override
	public void destroy() {
		logger.info("QueueIt Integration Filter destroyed");
	}

	/**
	 * Internal method to get integration configuration without HTTP response
	 */
	public String getIntegrationConfigurationInternal() {
		try {
			// Use the same pattern as IntegrationConfigProvider
			String url = String.format("https://%s.queue-it.net/status/integrationconfig/secure/%s", CUSTOMER_ID,
					CUSTOMER_ID);
			return getJsonText(url);
		}
		catch (Exception e) {
			logger.error("Failed to get integration configuration", e);
			return null;
		}
	}

	private String getJsonText(String url) throws IOException {
		java.net.URL resource = new java.net.URL(url);
		java.net.URLConnection connection = resource.openConnection();
		connection.setRequestProperty("api-key", API_KEY);
		connection.setConnectTimeout(4000);
		connection.setReadTimeout(4000);

		java.io.BufferedReader in = new java.io.BufferedReader(
				new java.io.InputStreamReader(connection.getInputStream()));
		StringBuilder response = new StringBuilder();
		String inputLine;
		while ((inputLine = in.readLine()) != null) {
			response.append(inputLine);
		}
		in.close();
		return response.toString();
	}

	/**
	 * Result class for queue validation
	 */
	private static class QueueValidationResult {

		private boolean requiresRedirect;

		private String actionType;

		private String redirectUrl;

		private boolean isAjaxRequest;

		public boolean requiresRedirect() {
			return requiresRedirect;
		}

		public void setRequiresRedirect(boolean requiresRedirect) {
			this.requiresRedirect = requiresRedirect;
		}

		public String getActionType() {
			return actionType;
		}

		public void setActionType(String actionType) {
			this.actionType = actionType;
		}

		public String getRedirectUrl() {
			return redirectUrl;
		}

		public void setRedirectUrl(String redirectUrl) {
			this.redirectUrl = redirectUrl;
		}

		public boolean isAjaxRequest() {
			return isAjaxRequest;
		}

		public void setAjaxRequest(boolean ajaxRequest) {
			isAjaxRequest = ajaxRequest;
		}

	}

}