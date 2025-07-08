package org.springframework.samples.petclinic.config;

import com.queue_it.connector.KnownUser;
import com.queue_it.connector.RequestValidationResult;
import com.queue_it.connector.models.ConnectorSettings;
import jakarta.servlet.*;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.io.IOException;

//@Component
@WebFilter("/*")  // Disabled to prevent QueueIt redirects
public class QueueItFilter implements Filter {

    private static final Logger logger = LoggerFactory.getLogger(QueueItFilter.class);

    @Autowired
    private ConnectorSettings connectorSettings;

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
            // Check if user has a valid queue token
            String queueitToken = httpRequest.getParameter(QueueItConfig.QUEUEIT_TOKEN_KEY);
            
            if (queueitToken == null || queueitToken.isEmpty()) {
                // No token - redirect to queue
                String targetUrl = buildTargetUrl(httpRequest);
                String queueUrl = buildQueueUrl(targetUrl);
                logger.info("No token, redirecting to queue: {}", queueUrl);
                httpResponse.sendRedirect(queueUrl);
                return;
            }

            // Validate token (simplified validation)
            if (!isValidToken(queueitToken)) {
                // Invalid token - redirect to queue
                String targetUrl = buildTargetUrl(httpRequest);
                String queueUrl = buildQueueUrl(targetUrl);
                logger.info("Invalid token, redirecting to queue: {}", queueUrl);
                httpResponse.sendRedirect(queueUrl);
                return;
            }

            // Token is valid - continue with request
            chain.doFilter(request, response);

        } catch (Exception e) {
            logger.error("Error in QueueIt filter", e);
            // Continue with the request on error
            chain.doFilter(request, response);
        }
    }

    private boolean shouldSkipQueueIt(String requestURI) {
        // Only protect specific high-value routes - everything else is public
        String[] protectedRoutes = { 
            "/owners/new",           // Add New Owner page
            "/owners/create",        // Create owner form submission
            "/owners/edit",          // Edit Owner page
            "/pets/new",             // Add New Pet page
            "/pets/create",          // Create pet form submission
            "/pets/edit",            // Edit Pet page
            "/visits/new",           // Add New Visit page
            "/visits/create",        // Create visit form submission
            "/visits/edit"           // Edit Visit page
        };

        // Check if this is a protected route
        for (String route : protectedRoutes) {
            if (requestURI.equals(route) || requestURI.startsWith(route)) {
                logger.debug("Protecting route: {}", requestURI);
                return false; // This route needs protection
            }
        }

        // Skip QueueIt for monitoring, integration, and system paths
        if (requestURI.startsWith("/actuator") ||
            requestURI.startsWith("/error") ||
            requestURI.startsWith("/grafana") ||
            requestURI.startsWith("/prometheus") ||
            requestURI.startsWith("/integration/queueit") ||
            requestURI.startsWith("/static") ||
            requestURI.startsWith("/css") ||
            requestURI.startsWith("/js") ||
            requestURI.startsWith("/images") ||
            requestURI.startsWith("/fonts") ||
            requestURI.startsWith("/webjars") ||
            requestURI.equals("/") ||
            requestURI.equals("/favicon.ico")) {
            logger.debug("Skipping QueueIt for: {}", requestURI);
            return true; // Skip protection for these paths
        }

        // Everything else is public (no protection)
        logger.debug("Public route (no protection): {}", requestURI);
        return true;
    }

    private String getIntegrationConfiguration() {
        try {
            String url = String.format("https://%s.queue-it.net/status/integrationconfig/secure/%s", 
                                     QueueItConfig.CUSTOMER_ID, QueueItConfig.CUSTOMER_ID);
            
            java.net.URL resource = new java.net.URL(url);
            java.net.URLConnection connection = resource.openConnection();
            connection.setRequestProperty("api-key", QueueItConfig.API_KEY);
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
        } catch (Exception e) {
            logger.error("Failed to get integration configuration", e);
            return null;
        }
    }

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        logger.info("QueueIt Filter initialized with official connector");
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

    private String buildQueueUrl(String targetUrl) {
        return String.format("https://%s.queue-it.net/queue?targetUrl=%s", 
                           QueueItConfig.CUSTOMER_ID, targetUrl);
    }

    private boolean isValidToken(String token) {
        // Simplified token validation - check if token is not empty and has reasonable format
        return token != null && !token.isEmpty() && token.length() > 10;
    }
} 