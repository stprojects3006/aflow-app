import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';
import { Trend, Counter, Rate } from 'k6/metrics';

export let options = {
    vus: __ENV.VUS ? parseInt(__ENV.VUS) : 50, // Virtual users
    stages: [
        { duration: '30s', target: 10 },  // Ramp up
        { duration: '1m', target: 50 },   // Stay at peak
        { duration: '30s', target: 0 },   // Ramp down
    ],
    // Use stages instead of duration for better control
    // duration: __ENV.DURATION || '2m',           // Test duration
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const ENDPOINTS = [
    '/integration/queueit/health',
    '/integration/queueit/status', 
    '/integration/queueit/queue',
    '/integration/queueit/validate',
    '/integration/queueit/cancel',
    '/integration/queueit/extend-cookie',
    '/owners/find',
    '/vets',
    '/owners/1',
    '/pets/1',
    '/'
];

// IP ranges for spoofing (common public IP ranges)
const IP_RANGES = [
    // North America
    { start: '192.168.1.1', end: '192.168.1.254' },
    { start: '10.0.0.1', end: '10.0.0.254' },
    { start: '172.16.0.1', end: '172.16.0.254' },
    // Europe
    { start: '193.0.0.1', end: '193.0.255.254' },
    { start: '194.0.0.1', end: '194.0.255.254' },
    // Asia
    { start: '202.0.0.1', end: '202.0.255.254' },
    { start: '203.0.0.1', end: '203.0.255.254' },
    // Mobile networks
    { start: '100.64.0.1', end: '100.64.255.254' },
    { start: '100.65.0.1', end: '100.65.255.254' },
];

// Custom metrics for enhanced monitoring
export const successfulResponses = new Counter('successful_responses');
export const errorResponses = new Counter('error_responses');
export const queueitRedirects = new Counter('queueit_redirects');
export const differentIPs = new Counter('unique_ips_used');
export const responseTime = new Trend('response_time');
export const errorRate = new Rate('error_rate');

// Track unique IPs used
const usedIPs = new Set();

// Function to generate random IP from ranges
function generateRandomIP() {
    const range = IP_RANGES[Math.floor(Math.random() * IP_RANGES.length)];
    const startParts = range.start.split('.').map(Number);
    const endParts = range.end.split('.').map(Number);
    
    const ip = startParts.map((start, i) => {
        const end = endParts[i];
        return Math.floor(Math.random() * (end - start + 1)) + start;
    }).join('.');
    
    return ip;
}

// Function to convert IP to integer for X-Forwarded-For header
function ipToInt(ip) {
    return ip.split('.').reduce((acc, octet) => (acc << 8) + parseInt(octet), 0) >>> 0;
}

export default function () {
    const sessionId = uuidv4();
    const endpoint = ENDPOINTS[Math.floor(Math.random() * ENDPOINTS.length)];
    const url = `${BASE_URL}${endpoint}`;
    
    // Generate random IP for this request
    const clientIP = generateRandomIP();
    usedIPs.add(clientIP);
    
    // Different headers for IP spoofing
    const headers = {
        'Content-Type': 'application/json',
        'User-Agent': `K6-LoadTest-${Math.floor(Math.random() * 1000)}`,
        'X-Forwarded-For': clientIP,
        'X-Real-IP': clientIP,
        'X-Client-IP': clientIP,
        'CF-Connecting-IP': clientIP, // Cloudflare
        'X-Forwarded-Host': 'loadtest.example.com',
        'X-Forwarded-Proto': 'https',
    };
    
    // Add QueueIt specific headers for integration endpoints
    if (endpoint.includes('/integration/queueit/')) {
        headers['api-key'] = __ENV.API_KEY || 'test-api-key';
        headers['customer-id'] = __ENV.CUSTOMER_ID || 'test-customer-id';
        headers['secret-key'] = __ENV.SECRET_KEY || 'test-secret-key';
    }
    
    const params = {
        headers: headers,
        timeout: '30s',
    };
    
    // Prepare payload based on endpoint
    let payload = null;
    if (endpoint.includes('/queue')) {
        payload = JSON.stringify({ userId: sessionId });
    } else if (endpoint.includes('/validate')) {
        payload = JSON.stringify({ token: `token-${sessionId}` });
    } else if (endpoint.includes('/cancel') || endpoint.includes('/extend-cookie')) {
        payload = JSON.stringify({ sessionId: sessionId });
    }
    
    const startTime = Date.now();
    const res = http.post(url, payload, params);
    const responseTimeMs = Date.now() - startTime;
    
    // Record response time
    responseTime.add(responseTimeMs);
    
    // Check response status and categorize
    const isSuccess = res.status >= 200 && res.status < 300;
    const isError = res.status >= 400;
    const isQueueitRedirect = (res.status >= 300 && res.status < 400) && 
                             res.headers['Location'] && 
                             res.headers['Location'].includes('queue-it.net');
    
    // Update metrics
    if (isSuccess) {
        successfulResponses.add(1);
    } else if (isError) {
        errorResponses.add(1);
        errorRate.add(1);
    }
    
    if (isQueueitRedirect) {
        queueitRedirects.add(1);
    }
    
    // Log request details for debugging
    if (__ENV.DEBUG === 'true') {
        console.log(`Request: ${endpoint} | IP: ${clientIP} | Status: ${res.status} | Time: ${responseTimeMs}ms`);
    }
    
    // Comprehensive checks
    check(res, {
        'status is success (2xx)': (r) => r.status >= 200 && r.status < 300,
        'status is client error (4xx)': (r) => r.status >= 400 && r.status < 500,
        'status is server error (5xx)': (r) => r.status >= 500,
        'redirected to Queue-it': (r) => isQueueitRedirect,
        'response time < 1000ms': (r) => responseTimeMs < 1000,
        'response time < 500ms': (r) => responseTimeMs < 500,
        'has content': (r) => r.body.length > 0,
    });
    
    // Add think time between requests
    sleep(Math.random() * 2 + 0.5); // Random sleep between 0.5-2.5 seconds
}

export function handleSummary(data) {
    console.log('=== K6 Load Test with IP Spoofing Summary ===');
    console.log(`Test Duration: ${data.state.testRunDuration}ms`);
    console.log(`Virtual Users: ${data.state.vus}`);
    console.log(`Total Requests: ${data.metrics.http_reqs ? data.metrics.http_reqs.count : 0}`);
    console.log(`Successful Responses: ${data.metrics.successful_responses ? data.metrics.successful_responses.count : 0}`);
    console.log(`Error Responses: ${data.metrics.error_responses ? data.metrics.error_responses.count : 0}`);
    console.log(`QueueIt Redirects: ${data.metrics.queueit_redirects ? data.metrics.queueit_redirects.count : 0}`);
    console.log(`Unique IPs Used: ${usedIPs.size}`);
    console.log(`Average Response Time: ${data.metrics.response_time ? data.metrics.response_time.avg : 0}ms`);
    console.log(`95th Percentile Response Time: ${data.metrics.response_time ? data.metrics.response_time.p(95) : 0}ms`);
    console.log(`Error Rate: ${data.metrics.error_rate ? (data.metrics.error_rate.rate * 100).toFixed(2) : 0}%`);
    
    // Log some sample IPs used
    const sampleIPs = Array.from(usedIPs).slice(0, 5);
    console.log(`Sample IPs Used: ${sampleIPs.join(', ')}`);
    
    return {
        'k6-load-test-results.json': JSON.stringify(data, null, 2),
    };
}

// Setup function to initialize test
export function setup() {
    console.log('Starting K6 Load Test with IP Spoofing...');
    console.log(`Target URL: ${BASE_URL}`);
    console.log(`Endpoints to test: ${ENDPOINTS.join(', ')}`);
    console.log(`IP Ranges configured: ${IP_RANGES.length} ranges`);
    return { startTime: Date.now() };
}

// Teardown function to clean up
export function teardown(data) {
    console.log('K6 Load Test with IP Spoofing completed.');
    console.log(`Total unique IPs used: ${usedIPs.size}`);
} 