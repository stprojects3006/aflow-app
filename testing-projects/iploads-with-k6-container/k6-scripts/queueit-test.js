import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.1/index.js";

// Custom metrics
const queueitRedirects = new Counter('queueit_redirects');
const queueitErrors = new Counter('queueit_errors');
const responseTime = new Trend('response_time');
const successRate = new Rate('success_rate');

// Test configuration
const config = {
  baseUrl: __ENV.TARGET_URL || 'https://affluenceit.com',
  protectedEndpoint: __ENV.PROTECTED_ENDPOINT || '/owners/new',
  healthEndpoint: __ENV.HEALTH_ENDPOINT || '/integration/queueit/health',
  publicEndpoint: __ENV.PUBLIC_ENDPOINT || '/',
  sleepTime: __ENV.SLEEP_TIME || 1,
  taskId: __ENV.TASK_ID || 'unknown'
};

// Test options
export const options = {
  stages: [
    { duration: '30s', target: 10 }, // Ramp up to 10 VUs
    { duration: '60s', target: 10 }, // Steady load with 10 VUs
    { duration: '30s', target: 0 }, // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<2000'],
    'http_req_failed': ['rate<0.1'],
    'queueit_redirects': ['count>0'],
    'success_rate': ['rate>0.9'],
  },
};

// Helper function to log with task ID
function log(message) {
  console.log(`[Task ${config.taskId}] ${message}`);
}

// Main test function
export default function () {
  const baseUrl = config.baseUrl;
  
  group('QueueIt Protected Endpoint Test', function () {
    log('Testing protected endpoint: ' + config.protectedEndpoint);
    
    const startTime = Date.now();
    const response = http.get(`${baseUrl}${config.protectedEndpoint}`, {
      headers: {
        'User-Agent': `k6-load-test/${config.taskId}`,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      },
      timeout: '30s',
    });
    
    const duration = Date.now() - startTime;
    responseTime.add(duration);
    
    // Check for QueueIt redirect
    const isRedirect = check(response, {
      'status is 302': (r) => r.status === 302,
      'redirects to QueueIt': (r) => r.headers.Location && r.headers.Location.includes('queue-it'),
      'has location header': (r) => r.headers.Location !== undefined,
    });
    
    if (isRedirect) {
      queueitRedirects.add(1);
      log(`✅ Redirected to QueueIt: ${response.headers.Location}`);
    } else {
      log(`❌ No redirect: Status ${response.status}, Location: ${response.headers.Location}`);
    }
    
    // Additional checks
    check(response, {
      'response time < 5s': (r) => r.timings.duration < 5000,
      'has content': (r) => r.body.length > 0,
    });
    
    successRate.add(response.status < 400);
  });
  
  group('QueueIt Health Check', function () {
    log('Testing health endpoint: ' + config.healthEndpoint);
    
    const healthResponse = http.get(`${baseUrl}${config.healthEndpoint}`, {
      headers: {
        'User-Agent': `k6-load-test/${config.taskId}`,
        'Accept': 'application/json',
      },
      timeout: '10s',
    });
    
    check(healthResponse, {
      'health status is 200': (r) => r.status === 200,
      'health response time < 2s': (r) => r.timings.duration < 2000,
    });
    
    if (healthResponse.status !== 200) {
      queueitErrors.add(1);
      log(`❌ Health check failed: Status ${healthResponse.status}`);
    } else {
      log('✅ Health check passed');
    }
  });
  
  group('Public Endpoint Test', function () {
    log('Testing public endpoint: ' + config.publicEndpoint);
    
    const publicResponse = http.get(`${baseUrl}${config.publicEndpoint}`, {
      headers: {
        'User-Agent': `k6-load-test/${config.taskId}`,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
      timeout: '10s',
    });
    
    check(publicResponse, {
      'public status is 200': (r) => r.status === 200,
      'public response time < 3s': (r) => r.timings.duration < 3000,
    });
    
    if (publicResponse.status === 200) {
      log('✅ Public endpoint accessible');
    } else {
      log(`❌ Public endpoint failed: Status ${publicResponse.status}`);
    }
  });
  
  sleep(config.sleepTime);
}

// Handle test completion
export function handleSummary(data) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const taskId = config.taskId;
  
  return {
    [`/tmp/k6-results-${taskId}-${timestamp}.json`]: JSON.stringify(data),
    [`/tmp/k6-results-${taskId}-${timestamp}.html`]: htmlReport(data),
    [`/tmp/k6-summary-${taskId}-${timestamp}.txt`]: textSummary(data, { indent: ' ', enableColors: true }),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

// Setup function
export function setup() {
  log('🚀 Starting QueueIt Load Test');
  log(`📊 Target URL: ${config.baseUrl}`);
  log(`🎯 Protected Endpoint: ${config.protectedEndpoint}`);
  log(`⏱️  Test Duration: ${options.stages.reduce((sum, stage) => sum + parseInt(stage.duration), 0)}s`);
  log(`🔢 Task ID: ${config.taskId}`);
}

// Teardown function
export function teardown(data) {
  log('🏁 Test completed');
  log(`📈 Total requests: ${data.metrics.http_reqs.values.count}`);
  log(`✅ Success rate: ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%`);
  log(`🔄 QueueIt redirects: ${data.metrics.queueit_redirects.values.count}`);
  log(`❌ QueueIt errors: ${data.metrics.queueit_errors.values.count}`);
} 