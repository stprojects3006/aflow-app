import http from 'k6/http';
import { check, sleep } from 'k6';

export default function () {
  const baseUrl = 'https://affluenceit.com';
  
  // Test /owners/new endpoint (should redirect to QueueIt)
  const response = http.get(`${baseUrl}/owners/new`);
  
  check(response, {
    'status is 302 (redirect)': (r) => r.status === 302,
    'redirects to QueueIt': (r) => r.headers.Location && r.headers.Location.includes('queue-it'),
  });
  
  // Test health endpoint
  const healthResponse = http.get(`${baseUrl}/integration/queueit/health`);
  check(healthResponse, {
    'health check works': (r) => r.status === 200,
  });
  
  sleep(1);
} 