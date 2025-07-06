import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Stress test configuration
export const options = {
  stages: [
    { duration: '2m', target: 20 },   // Ramp up to 20 users
    { duration: '3m', target: 20 },   // Stay at 20 users
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '3m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '3m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 200 },  // Ramp up to 200 users
    { duration: '5m', target: 200 },  // Stay at 200 users
    { duration: '2m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'], // 95% of requests should be below 5s
    http_req_failed: ['rate<0.2'],     // Error rate should be less than 20%
    errors: ['rate<0.2'],
  },
};

// Test data
const BASE_URL = __ENV.TARGET_URL || 'https://affluenceit.com/';

// SSL configuration for sites with certificate issues
const SSL_CONFIG = {
  insecureSkipTLSVerify: true
};

// Different types of requests to simulate real load for PetClinic
const requestTypes = [
  // Light requests
  () => http.get(`${BASE_URL}/`, SSL_CONFIG),
  () => http.get(`${BASE_URL}/owners`, SSL_CONFIG),
  
  // Medium requests
  () => http.get(`${BASE_URL}/vets`, SSL_CONFIG),
  () => http.get(`${BASE_URL}/owners/find`, SSL_CONFIG),
  
  // Heavy requests
  () => http.get(`${BASE_URL}/owners/1`, SSL_CONFIG),
  () => http.get(`${BASE_URL}/owners/2`, SSL_CONFIG),
];

// Main test function
export default function () {
  // Randomly select a request type
  const requestType = requestTypes[Math.floor(Math.random() * requestTypes.length)];
  
  // Execute the request
  const response = requestType();
  
  // Check response
  const success = check(response, {
    'request successful': (r) => r.status === 200 || r.status === 201,
    'response time acceptable': (r) => r.timings.duration < 10000,
  });
  
  // Record errors
  errorRate.add(!success);
  
  // Shorter think time for stress test
  sleep(Math.random() * 1 + 0.5);
}

// Setup function
export function setup() {
  console.log(`Starting stress test against: ${BASE_URL}`);
  
  // Verify the target is reachable
  const response = http.get(`${BASE_URL}/`, SSL_CONFIG);
  if (response.status !== 200) {
    throw new Error(`Target application is not responding: ${response.status}`);
  }
  
  return { targetUrl: BASE_URL };
}

// Teardown function
export function teardown(data) {
  console.log(`Stress test completed for: ${data.targetUrl}`);
} 