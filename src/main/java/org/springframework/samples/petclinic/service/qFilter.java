package org.springframework.samples.petclinic.service;

import java.io.IOException;
import java.util.regex.Pattern;

//Queue-it Connector Imports
import com.queue_it.connector.ConnectorContextProvider;
import com.queue_it.connector.KnownUser;
import com.queue_it.connector.RequestValidationResult;
import com.queue_it.connector.integrationconfig.CustomerIntegration;
import com.queue_it.connector.models.ConnectorSettings;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.FilterConfig;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.samples.petclinic.service.QueueItSettings;

//import com.queue_it.connector.Utils; //For v4.2.2 and later — remove or comment this line for older versions

@WebFilter("/*")
// This annotation applies the filter to all servlets.
// qFilter should be set as the first filter to process incoming requests.
// This ensures that requests are validated immediately upon receiving
// and, if necessary, redirected to the waiting room before any business logic is
// executed.
public class qFilter implements Filter {

	private static final Logger logger = LoggerFactory.getLogger(qFilter.class);

	private QueueItSettings queueItSettings;

	@Autowired
	public void setQueueItSettings(QueueItSettings queueItSettings) {
		this.queueItSettings = queueItSettings;
	}

	@Override
	public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
			throws IOException, ServletException { // This is the method called every time
													// a request/response passes through
													// the filter

		logger.info("Passing through filter....FFCS");
		// Call the validation function before the rest of the filter chain is processed
		boolean proceed = doValidation((HttpServletRequest) request, (HttpServletResponse) response);

		// Passes the request along the filter chain
		if (proceed && !response.isCommitted()) {
			chain.doFilter((HttpServletRequest) request, (HttpServletResponse) response);
		}
	}

	private boolean doValidation(HttpServletRequest request, HttpServletResponse response) {
		try {
			String customerId = queueItSettings.getCustomerId();
			String secretKey = queueItSettings.getSecretKey();
			String apiKey = queueItSettings.getApiKey();

			// The pureUrl is used to match Integration Triggers and as the Target URL
			// (where to return the users to).
			// It is therefore important that the pureUrl is exactly the URL sent from the
			// end-users' browsers.
			// So, if your webserver is e.g. behind a load balancer that modifies the host
			// name and/or port etc.,
			// then reformat the pureUrl in the the GetPureUrl function below before
			// proceeding.
			String pureUrl = getPureUrl(request);

			ConnectorSettings connectorSettings = new ConnectorSettings(customerId, secretKey, apiKey);
			// For older versions before v4.2.2, you should use the locally defined
			// getParameterFromQueryString method instead
			String queueitToken = getParameterFromQueryString(request, KnownUser.QUEUEIT_TOKEN_KEY);
			// String queueitToken =
			// Utils.getParameterFromQueryString(request.getQueryString(),
			// KnownUser.QUEUEIT_TOKEN_KEY);

			// Download and cache using polling
			CustomerIntegration integrationConfig = IntegrationConfigProvider.getCachedIntegrationConfig(customerId,
					apiKey);

			// Create an instance of the ConnectorContextProvider
			ConnectorContextProvider connectorContextProvider = new ConnectorContextProvider(connectorSettings, request,
					response);

			// Verify if the user has been through the queue
			RequestValidationResult validationResult = KnownUser.validateRequestByIntegrationConfig(pureUrl,
					queueitToken, integrationConfig, customerId, secretKey, connectorContextProvider);

			if (validationResult.doRedirect()) {
				if (validationResult.isAjaxResult) {
					// Adding no cache headers to prevent browsers to cache requests
					response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate, max-age=0"); // HTTP
																											// 1.1
					response.setHeader("Pragma", "no-cache"); // HTTP 1.0
					response.setHeader("Expires", "Fri, 01 Jan 1990 00:00:00 GMT"); // Proxies.
					// end

					// In case of ajax call send the user to the queue by sending a custom
					// queue-it
					// header and redirecting user to queue from javascript
					response.setHeader(validationResult.getAjaxQueueRedirectHeaderKey(),
							validationResult.getAjaxRedirectUrl());
					response.setHeader("Access-Control-Expose-Headers",
							validationResult.getAjaxQueueRedirectHeaderKey());
				}
				else {
					// Send the user to the queue - either because hash was missing or
					// because is was invalid
					response.sendRedirect(validationResult.getRedirectUrl());
				}
				response.getOutputStream().flush();
				response.getOutputStream().close();
				return false;
			}
			else {
				String queryString = request.getQueryString();
				// Request can continue - we remove queueittoken form querystring
				// parameter to avoid sharing of user specific token if there was a match
				if (queryString != null && queryString.contains(KnownUser.QUEUEIT_TOKEN_KEY)
						&& "Queue".equals(validationResult.getActionType())) {
					response.sendRedirect(pureUrl);
					response.getOutputStream().flush();
					response.getOutputStream().close();
				}
			}
		}
		catch (Exception ex) {
			// There was an error validating the request
			// Use your own logging framework to log the Exception
			// This was a configuration exception, so we let the user continue
		}
		return true;
	}

	// Helper method to get url without token.
	// It uses patterns which is unsupported in Java 6, so if you are using this version
	// please reach out to us.
	private String getPureUrl(HttpServletRequest request) {
		// Cleans the request URL by removing the Queue-it token and enforcing HTTPS if
		// needed.
		// Remove the token query parameter from the URL
		Pattern pattern = Pattern.compile("([\\?&])(" + KnownUser.QUEUEIT_TOKEN_KEY + "=[^&]*)",
				Pattern.CASE_INSENSITIVE);
		String queryString = request.getQueryString();
		String url = request.getRequestURL().toString() + (queryString != null ? ("?" + queryString) : "");

		String pureUrl = pattern.matcher(url).replaceAll("");

		// Ensure the URL uses HTTPS instead of HTTP (replacing only the first occurrence
		// of http).
		// If your web-server already receives HTTPS URL then comment the below out.
		pureUrl = pureUrl.replaceFirst("(?i)^http://([^/?#]+)", "http://$1");

		return pureUrl;
	}

	// NOTE: For older versions only — not needed in v4.2.2+
	// Helper to get a parameter from the url query string
	private String getParameterFromQueryString(HttpServletRequest request, String key) {
		String queryString = request.getQueryString();
		if (key == null || key.isEmpty() || queryString == null || queryString.isEmpty())
			return "";

		String[] params = queryString.split("&");

		for (String param : params) {
			String[] paramParts = param.split("=");
			if (paramParts.length >= 0 && paramParts[0].equals(key)) {
				return paramParts[1];
			}
		}
		return "";
	}

	@Override
	public void init(FilterConfig filterConfig) throws ServletException {
		// TODO Auto-generated method stub
	}

	@Override
	public void destroy() {
		// TODO Auto-generated method stub
	}

}
