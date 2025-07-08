import http from 'k6/http';
import { check, sleep } from 'k6';

// Configuration
export const options = {
  vus: 5,
  duration: '60s',
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests should be below 2s
    http_req_failed: ['rate<0.1'],     // Error rate should be less than 10%
  },
};

// Test scenarios
export default function () {
  // Test the main application endpoints
  const baseUrl = 'http://ec2-54-237-232-85.compute-1.amazonaws.com';
  
  // Test 1: Home page (should be accessible)
  const homeResponse = http.get(`${baseUrl}/`);
  check(homeResponse, {
    'home page status is 200': (r) => r.status === 200,
    'home page loads quickly': (r) => r.timings.duration < 1000,
  });
  
  // Test 2: Owners page (should redirect to QueueIt)
  const ownersResponse = http.get(`${baseUrl}/owners`);
  check(ownersResponse, {
    'owners page redirects (302)': (r) => r.status === 302,
    'redirects to QueueIt': (r) => r.headers.Location && r.headers.Location.includes('queue-it'),
  });
  
  // Test 3: Vets page (should redirect to QueueIt)
  const vetsResponse = http.get(`${baseUrl}/vets`);
  check(vetsResponse, {
    'vets page redirects (302)': (r) => r.status === 302,
    'redirects to QueueIt': (r) => r.headers.Location && r.headers.Location.includes('queue-it'),
  });
  
  // Test 4: Error page (should be accessible)
  const errorResponse = http.get(`${baseUrl}/oups`);
  check(errorResponse, {
    'error page status is 200': (r) => r.status === 200,
  });
  
  // Test 5: Static resources (should be accessible)
  const cssResponse = http.get(`${baseUrl}/resources/css/petclinic.css`);
  check(cssResponse, {
    'CSS loads successfully': (r) => r.status === 200,
  });
  
  // Add some randomness and think time
  sleep(Math.random() * 2 + 1); // Random sleep between 1-3 seconds
} 