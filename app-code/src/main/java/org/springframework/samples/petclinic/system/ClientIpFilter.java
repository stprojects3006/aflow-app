package org.springframework.samples.petclinic.system;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Tag;
import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

@Component
public class ClientIpFilter implements Filter {

	private final MeterRegistry meterRegistry;

	public ClientIpFilter(MeterRegistry meterRegistry) {
		this.meterRegistry = meterRegistry;
	}

	@Override
	public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
			throws IOException, ServletException {

		HttpServletRequest httpRequest = (HttpServletRequest) request;
		HttpServletResponse httpResponse = (HttpServletResponse) response;

		// Get client IP address
		String clientIp = getClientIpAddress(httpRequest);

		// Create a wrapper to capture the response status
		ResponseStatusCapturingWrapper responseWrapper = new ResponseStatusCapturingWrapper(httpResponse);

		try {
			chain.doFilter(request, responseWrapper);
		}
		finally {
			// Record the request with client IP
			recordRequestWithClientIp(httpRequest, responseWrapper, clientIp);
		}
	}

	private String getClientIpAddress(HttpServletRequest request) {
		// Check for X-Forwarded-For header (for proxy scenarios)
		String xForwardedFor = request.getHeader("X-Forwarded-For");
		if (xForwardedFor != null && !xForwardedFor.isEmpty() && !"unknown".equalsIgnoreCase(xForwardedFor)) {
			return xForwardedFor.split(",")[0].trim();
		}

		// Check for X-Real-IP header
		String xRealIp = request.getHeader("X-Real-IP");
		if (xRealIp != null && !xRealIp.isEmpty() && !"unknown".equalsIgnoreCase(xRealIp)) {
			return xRealIp;
		}

		// Check for X-Client-IP header
		String xClientIp = request.getHeader("X-Client-IP");
		if (xClientIp != null && !xClientIp.isEmpty() && !"unknown".equalsIgnoreCase(xClientIp)) {
			return xClientIp;
		}

		// Fall back to remote address
		return request.getRemoteAddr();
	}

	private void recordRequestWithClientIp(HttpServletRequest request, ResponseStatusCapturingWrapper response,
			String clientIp) {
		try {
			String uri = request.getRequestURI();
			String method = request.getMethod();
			int status = response.getStatus();

			// Create tags for the metric
			List<Tag> tags = new ArrayList<>();
			tags.add(Tag.of("uri", uri));
			tags.add(Tag.of("method", method));
			tags.add(Tag.of("status", String.valueOf(status)));
			tags.add(Tag.of("client_ip", clientIp));

			// Increment the counter
			meterRegistry.counter("http_server_requests_seconds_count", tags).increment();

			// Also record timing
			meterRegistry.timer("http_server_requests_seconds", tags);

		}
		catch (Exception e) {
			// Log but don't fail the request
			System.err.println("Error recording client IP metric: " + e.getMessage());
		}
	}

	// Wrapper to capture response status
	private static class ResponseStatusCapturingWrapper extends jakarta.servlet.http.HttpServletResponseWrapper {

		private int status = 200;

		public ResponseStatusCapturingWrapper(HttpServletResponse response) {
			super(response);
		}

		@Override
		public void setStatus(int status) {
			this.status = status;
			super.setStatus(status);
		}

		@Override
		public void sendError(int status) throws IOException {
			this.status = status;
			super.sendError(status);
		}

		@Override
		public void sendError(int status, String message) throws IOException {
			this.status = status;
			super.sendError(status, message);
		}

		public int getStatus() {
			return status;
		}

	}

}