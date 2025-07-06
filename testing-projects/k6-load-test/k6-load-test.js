import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';
import { Trend, Counter } from 'k6/metrics';

export let options = {
    vus: __ENV.VUS ? parseInt(__ENV.VUS) : 100000, // Virtual users
    duration: __ENV.DURATION || '1m',           // Test duration
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const ENDPOINTS = ['/integration/queueit/queue', '/integration/queueit/enqueue'];
const API_KEY = __ENV.API_KEY || 'your-api-key';
const CUSTOMER_ID = __ENV.CUSTOMER_ID || 'your-customer-id';
const SECRET_KEY = __ENV.SECRET_KEY || 'your-secret-key';
const QUEUE_NAME = __ENV.QUEUE_NAME || 'default-queue';

// Custom metrics for Grafana
export const successfulResponses = new Counter('successful_responses');
export const queueitRedirects = new Counter('queueit_redirects');
export const inflow = new Counter('inflow');
export const waiting = new Counter('waiting');
export const outflow = new Counter('outflow');

export default function () {
    const sessionId = uuidv4();
    // Randomly pick /queue or /enqueue endpoint
    const endpoint = ENDPOINTS[Math.floor(Math.random() * ENDPOINTS.length)];
    const url = `${BASE_URL}${endpoint}`;
    const payload = JSON.stringify({ userId: sessionId });
    const params = {
        headers: {
            'Content-Type': 'application/json',
            'api-key': API_KEY,
            'customer-id': CUSTOMER_ID,
            'secret-key': SECRET_KEY,
        },
        timeout: '30s',
    };
    inflow.add(1); // Count every request sent
    const res = http.post(url, payload, params);
    const isSuccess = res.status === 200;
    const isQueueitRedirect = (res.status >= 300 && res.status < 400) && res.headers['Location'] && res.headers['Location'].includes('queue-it.net');
    check(res, {
        'status is 200': (r) => isSuccess,
        'redirected to Queue-it': (r) => isQueueitRedirect,
    });
    if (isQueueitRedirect) {
        waiting.add(1);
        // Try to extract queue name from the redirect URL if present
        let queueName = QUEUE_NAME;
        const match = res.headers['Location'] && res.headers['Location'].match(/queue-it\.net\/([^\/?]+)/);
        if (match && match[1]) {
            queueName = match[1];
        }
        console.log(`Waiting (redirected to Queue-it): Queue Name: ${queueName}, URL: ${res.headers['Location']}`);
    }
    if (isSuccess) {
        outflow.add(1);
    }
    // sleep(0.1); // Optional: add small sleep to simulate user think time
}

export function handleSummary(data) {
    // Log max inflow, waiting, and outflow at the end of the test
    console.log('--- K6 Test Summary ---');
    console.log(`Queue Name: ${QUEUE_NAME}`);
    console.log(`Max Inflow (requests sent): ${data.metrics.inflow ? data.metrics.inflow.count : 0}`);
    console.log(`Waiting (redirected to Queue-it): ${data.metrics.waiting ? data.metrics.waiting.count : 0}`);
    console.log(`Max Outflow (successful responses): ${data.metrics.outflow ? data.metrics.outflow.count : 0}`);
    return {};
} 