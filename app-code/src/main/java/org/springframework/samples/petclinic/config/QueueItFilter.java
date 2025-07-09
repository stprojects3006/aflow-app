package org.springframework.samples.petclinic.config;

import com.queue_it.connector.KnownUser;
import com.queue_it.connector.RequestValidationResult;
import com.queue_it.connector.models.ConnectorSettings;
import com.queue_it.connector.integrationconfig.CustomerIntegration;
import com.queue_it.connector.IConnectorContextProvider;
import com.queue_it.connector.ConnectorContextProvider;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.DeserializationFeature;
import jakarta.servlet.*;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.samples.petclinic.integration.QueueItSettings;
import org.springframework.samples.petclinic.integration.QueueItIntegrationController;
import org.springframework.stereotype.Component;

import java.io.IOException;

//@Component
@WebFilter("/*") // Enable QueueIt filter
public class QueueItFilter implements Filter {

	private static final Logger logger = LoggerFactory.getLogger(QueueItFilter.class);

	@Autowired
	private ConnectorSettings connectorSettings;

	@Autowired
	private QueueItSettings queueItSettings;

	@Autowired
	private QueueItIntegrationController queueItController;

	@Override
	public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
			throws IOException, ServletException {

		HttpServletRequest httpRequest = (HttpServletRequest) request;
		HttpServletResponse httpResponse = (HttpServletResponse) response;

		// Skip QueueIt for certain paths
		String requestURI = httpRequest.getRequestURI();
		if (shouldSkipQueueIt(requestURI)) {
			chain.doFilter(request, response);
			return;
		}

		try {
			// Get integration configuration from QueueIt API
			String integrationConfigJson = getIntegrationConfiguration();
			if (integrationConfigJson == null) {
				logger.error("Failed to get integration configuration, allowing request through");
				chain.doFilter(request, response);
				return;
			}

			// Parse integration configuration using Jackson with ignore unknown properties
			ObjectMapper mapper = new ObjectMapper();
			mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
			CustomerIntegration customerIntegration = mapper.readValue(integrationConfigJson, CustomerIntegration.class);
			
			// Build target URL
			String targetUrl = buildTargetUrl(httpRequest);
			
			// Get queue token from request
			String queueitToken = httpRequest.getParameter(QueueItConfig.QUEUEIT_TOKEN_KEY);

			// Create context provider with required parameters
			IConnectorContextProvider contextProvider = new ConnectorContextProvider(
				connectorSettings, 
				httpRequest, 
				httpResponse
			);

			// Use official QueueIt SDK to validate request
			RequestValidationResult validationResult = KnownUser.validateRequestByIntegrationConfig(
				targetUrl, 
				queueitToken, 
				customerIntegration, 
				queueItSettings.getCustomerId(), 
				queueItSettings.getSecretKey(),
				contextProvider
			);

			// Handle validation result
			if (validationResult.doRedirect()) {
				// Redirect to queue
				logger.info("Redirecting to queue: {}", validationResult.getRedirectUrl());
				httpResponse.sendRedirect(validationResult.getRedirectUrl());
				return;
			}

			// Request is valid, continue
			chain.doFilter(request, response);

		}
		catch (Exception e) {
			logger.error("Error in QueueIt filter", e);
			// Continue with the request on error
			chain.doFilter(request, response);
		}
	}

	private boolean shouldSkipQueueIt(String requestURI) {
		// Only protect specific high-value routes - everything else is public
		String[] protectedRoutes = { "/owners/new", // Add New Owner page
				"/owners/create", // Create owner form submission
				"/owners/edit", // Edit Owner page
				"/pets/new", // Add New Pet page
				"/pets/create", // Create pet form submission
				"/pets/edit", // Edit Pet page
				"/visits/new", // Add New Visit page
				"/visits/create", // Create visit form submission
				"/visits/edit" // Edit Visit page
		};

		// Check if this is a protected route
		for (String route : protectedRoutes) {
			if (requestURI.equals(route) || requestURI.startsWith(route)) {
				logger.debug("Protecting route: {}", requestURI);
				return false; // This route needs protection
			}
		}

		// Skip QueueIt for monitoring, integration, and system paths
		if (requestURI.startsWith("/actuator") || requestURI.startsWith("/error") || requestURI.startsWith("/grafana")
				|| requestURI.startsWith("/prometheus") || requestURI.startsWith("/integration/queueit")
				|| requestURI.startsWith("/static") || requestURI.startsWith("/css") || requestURI.startsWith("/js")
				|| requestURI.startsWith("/images") || requestURI.startsWith("/fonts")
				|| requestURI.startsWith("/webjars") || requestURI.equals("/") || requestURI.equals("/favicon.ico")) {
			logger.debug("Skipping QueueIt for: {}", requestURI);
			return true; // Skip protection for these paths
		}

		// Everything else is public (no protection)
		logger.debug("Public route (no protection): {}", requestURI);
		return true;
	}

	private String getIntegrationConfiguration() {
		try {
			// Use the controller's method to get integration configuration
			return queueItController.getIntegrationConfigurationInternal();
		}
		catch (Exception e) {
			logger.error("Failed to get integration configuration", e);
			return null;
		}
	}

	@Override
	public void init(FilterConfig filterConfig) throws ServletException {
		logger.info("QueueIt Filter initialized with official connector SDK");
	}

	@Override
	public void destroy() {
		logger.info("QueueIt Filter destroyed");
	}

	private String buildTargetUrl(HttpServletRequest request) {
		String scheme = request.getScheme();
		String hostHeader = request.getHeader("Host");
		String uri = request.getRequestURI();
		String queryString = request.getQueryString();

		StringBuilder url = new StringBuilder();
		url.append(scheme).append("://").append(hostHeader).append(uri);
		if (queryString != null && !queryString.isEmpty()) {
			url.append("?").append(queryString);
		}

		// Remove queueittoken param if present
		String urlStr = url.toString();
		if (urlStr.contains("queueittoken=")) {
			urlStr = urlStr.replaceAll("[?&]queueittoken=[^&]*", "");
			if (urlStr.endsWith("?")) {
				urlStr = urlStr.substring(0, urlStr.length() - 1);
			}
		}

		return urlStr;
	}

}