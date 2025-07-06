import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 },  // Ramp up to 10 users
    { duration: '5m', target: 10 },  // Stay at 10 users
    { duration: '2m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests should be below 2s
    http_req_failed: ['rate<0.1'],     // Error rate should be less than 10%
    errors: ['rate<0.1'],
  },
};

// Test data
const BASE_URL = __ENV.TARGET_URL || 'https://affluenceit.com/';

// SSL configuration for sites with certificate issues
const SSL_CONFIG = {
  insecureSkipTLSVerify: true
};

// Simulate different user behaviors for PetClinic application
const userFlows = [
  // Flow 1: Homepage visitor
  () => {
    const response = http.get(`${BASE_URL}/`, SSL_CONFIG);
    check(response, {
      'homepage loads successfully': (r) => r.status === 200,
      'homepage response time < 2s': (r) => r.timings.duration < 2000,
    });
    return response.status === 200;
  },
  
  // Flow 2: View owners page
  () => {
    const response = http.get(`${BASE_URL}/owners`, SSL_CONFIG);
    check(response, {
      'owners page loads': (r) => r.status === 200,
      'owners page response time < 3s': (r) => r.timings.duration < 3000,
    });
    return response.status === 200;
  },
  
  // Flow 3: View veterinarians page
  () => {
    const response = http.get(`${BASE_URL}/vets`, SSL_CONFIG);
    check(response, {
      'vets page loads': (r) => r.status === 200,
      'vets page response time < 3s': (r) => r.timings.duration < 3000,
    });
    return response.status === 200;
  },
];

// Main test function
export default function () {
  // Randomly select a user flow
  const selectedFlow = userFlows[Math.floor(Math.random() * userFlows.length)];
  
  // Execute the flow
  const success = selectedFlow();
  
  // Record errors
  errorRate.add(!success);
  
  // Think time between requests (1-3 seconds)
  sleep(Math.random() * 2 + 1);
}

// Setup function (runs once at the beginning)
export function setup() {
  console.log(`Starting load test against: ${BASE_URL}`);
  
  // Verify the target is reachable
  const response = http.get(`${BASE_URL}/`, SSL_CONFIG);
  if (response.status !== 200) {
    throw new Error(`Target application is not responding: ${response.status}`);
  }
  
  return { targetUrl: BASE_URL };
}

// Teardown function (runs once at the end)
export function teardown(data) {
  console.log(`Load test completed for: ${data.targetUrl}`);
  
  // Upload results to S3 if S3_BUCKET is set
  if (__ENV.S3_BUCKET) {
    console.log('Uploading results to S3...');
    // The upload script will be called after k6 completes
  }
} 