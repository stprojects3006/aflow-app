import http from 'k6/http';
import { check, sleep } from 'k6';

// Configuration
export const options = {
  vus: 10,
  duration: '120s',
  thresholds: {
    http_req_duration: ['p(95)<3000'], // 95% of requests should be below 3s
    http_req_failed: ['rate<0.2'],     // Error rate should be less than 20%
  },
};

// Test scenarios
export default function () {
  const baseUrl = 'https://affluenceit.com';
  
  // Test 1: Main focus - /owners/new endpoint (should redirect to QueueIt)
  const ownersNewResponse = http.get(`${baseUrl}/owners/new`);
  check(ownersNewResponse, {
    'owners/new endpoint redirects (302)': (r) => r.status === 302,
    'redirects to QueueIt': (r) => r.headers.Location && r.headers.Location.includes('queue-it'),
    'owners/new response time < 2s': (r) => r.timings.duration < 2000,
  });
  
  // Test 2: QueueIt integration health check
  const healthResponse = http.get(`${baseUrl}/integration/queueit/health`);
  check(healthResponse, {
    'QueueIt health check status is 200': (r) => r.status === 200,
    'health check response time < 1s': (r) => r.timings.duration < 1000,
  });
  
  // Test 3: QueueIt status endpoint
  const statusResponse = http.get(`${baseUrl}/integration/queueit/status`);
  check(statusResponse, {
    'QueueIt status endpoint accessible': (r) => r.status === 200,
  });
  
  // Test 4: QueueIt session info
  const sessionResponse = http.get(`${baseUrl}/integration/queueit/session-info`);
  check(sessionResponse, {
    'QueueIt session info accessible': (r) => r.status === 200,
  });
  
  // Test 5: QueueIt validation endpoint
  const validateResponse = http.get(`${baseUrl}/integration/queueit/validate`);
  check(validateResponse, {
    'QueueIt validation endpoint accessible': (r) => r.status === 200,
  });
  
  // Test 6: Other protected routes that should redirect to QueueIt
  const protectedRoutes = [
    '/owners',
    '/vets',
    '/pets/new'
  ];
  
  const randomRoute = protectedRoutes[Math.floor(Math.random() * protectedRoutes.length)];
  const protectedResponse = http.get(`${baseUrl}${randomRoute}`);
  check(protectedResponse, {
    'protected route redirects (302)': (r) => r.status === 302,
    'redirects to QueueIt': (r) => r.headers.Location && r.headers.Location.includes('queue-it'),
  });
  
  // Test 7: Public routes that should be accessible
  const publicRoutes = [
    '/',
    '/oups',
    '/resources/css/petclinic.css'
  ];
  
  const randomPublicRoute = publicRoutes[Math.floor(Math.random() * publicRoutes.length)];
  const publicResponse = http.get(`${baseUrl}${randomPublicRoute}`);
  check(publicResponse, {
    'public route accessible': (r) => r.status === 200,
  });
  
  // Test 8: QueueIt simulation endpoints
  const simulateResponse = http.get(`${baseUrl}/integration/queueit/simulate-event`);
  check(simulateResponse, {
    'QueueIt simulation endpoint accessible': (r) => r.status === 200,
  });
  
  // Test 9: QueueIt reset endpoint
  const resetResponse = http.get(`${baseUrl}/integration/queueit/reset-test-state`);
  check(resetResponse, {
    'QueueIt reset endpoint accessible': (r) => r.status === 200,
  });
  
  // Add some randomness and think time
  sleep(Math.random() * 3 + 1); // Random sleep between 1-4 seconds
} 