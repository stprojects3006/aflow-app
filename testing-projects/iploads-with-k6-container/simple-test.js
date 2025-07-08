import http from 'k6/http';
import { check, sleep } from 'k6';

// Test configuration
export const options = {
  vus: 5,
  duration: '60s',
  thresholds: {
    http_req_duration: ['p(95)<5000'],
    http_req_failed: ['rate<0.1'],
  },
};

// Test data
const BASE_URL = 'https://affluenceit.com';

// SSL configuration
const SSL_CONFIG = {
  insecureSkipTLSVerify: true
};

// Test endpoints for PetClinic
const endpoints = [
  '/',
  '/owners',
  '/vets',
];

export default function () {
  // Randomly select an endpoint
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  
  // Make the request
  const response = http.get(`${BASE_URL}${endpoint}`, SSL_CONFIG);
  
  // Check response
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 5s': (r) => r.timings.duration < 5000,
  });
  
  // Think time between requests
  sleep(2);
}

export function setup() {
  console.log('Starting simple test against:', BASE_URL);
  
  // Verify the target is reachable
  const response = http.get(`${BASE_URL}`, SSL_CONFIG);
  console.log('Setup check - Status:', response.status);
  
  if (response.status !== 200) {
    throw new Error(`Target application is not responding: ${response.status}`);
  }
  
  return { targetUrl: BASE_URL };
}

export function teardown(data) {
  console.log('Simple test completed for:', data.targetUrl);
} 