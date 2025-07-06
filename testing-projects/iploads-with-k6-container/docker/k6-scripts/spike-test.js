import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Spike test configuration
export const options = {
  stages: [
    { duration: '1m', target: 10 },   // Normal load: 10 users
    { duration: '30s', target: 100 }, // Spike: 100 users
    { duration: '1m', target: 100 },  // Stay at spike
    { duration: '30s', target: 10 },  // Back to normal
    { duration: '1m', target: 10 },   // Normal load
    { duration: '30s', target: 200 }, // Bigger spike: 200 users
    { duration: '1m', target: 200 },  // Stay at big spike
    { duration: '30s', target: 10 },  // Back to normal
    { duration: '1m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'], // 95% of requests should be below 3s
    http_req_failed: ['rate<0.15'],    // Error rate should be less than 15%
    errors: ['rate<0.15'],
  },
};

// Test data
const BASE_URL = __ENV.TARGET_URL || 'https://affluenceit.com/';

// SSL configuration for sites with certificate issues
const SSL_CONFIG = {
  insecureSkipTLSVerify: true
};

// Different endpoints to test for PetClinic
const endpoints = [
  '/',
  '/owners',
  '/vets',
  '/owners/find',
  '/owners/1',
];

// Main test function
export default function () {
  // Randomly select an endpoint
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  
  // Make the request
  const response = http.get(`${BASE_URL}${endpoint}`, SSL_CONFIG);
  
  // Check response
  const success = check(response, {
    'request successful': (r) => r.status === 200,
    'response time acceptable': (r) => r.timings.duration < 5000,
  });
  
  // Record errors
  errorRate.add(!success);
  
  // Very short think time for spike test
  sleep(Math.random() * 0.5 + 0.1);
}

// Setup function
export function setup() {
  console.log(`Starting spike test against: ${BASE_URL}`);
  
  // Verify the target is reachable
  const response = http.get(`${BASE_URL}/`, SSL_CONFIG);
  if (response.status !== 200) {
    throw new Error(`Target application is not responding: ${response.status}`);
  }
  
  return { targetUrl: BASE_URL };
}

// Teardown function
export function teardown(data) {
  console.log(`Spike test completed for: ${data.targetUrl}`);
} 