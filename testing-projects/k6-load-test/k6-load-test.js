import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

export let options = {
    vus: __ENV.VUS ? parseInt(__ENV.VUS) : 500000, // Virtual users
    duration: __ENV.DURATION || '1m',           // Test duration
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const ENDPOINTS = ['/integration/queueit/queue', '/integration/queueit/enqueue'];
const API_KEY = __ENV.API_KEY || 'your-api-key';
const CUSTOMER_ID = __ENV.CUSTOMER_ID || 'your-customer-id';
const SECRET_KEY = __ENV.SECRET_KEY || 'your-secret-key';

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
    const res = http.post(url, payload, params);
    check(res, {
        'status is 200': (r) => r.status === 200,
    });
    // sleep(0.1); // Optional: add small sleep to simulate user think time
} 