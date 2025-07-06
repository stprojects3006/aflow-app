import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics for IP rotation
const ip_rotation_success = new Rate('ip_rotation_success');
const unique_ips_used = new Rate('unique_ips_used');

// Configuration
const TARGET_URL = __ENV.TARGET_URL || 'https://affluenceit.com/';
const IP_ROTATION_ENABLED = __ENV.IP_ROTATION_ENABLED === 'true';
const PROXY_TYPE = __ENV.PROXY_TYPE || 'static';
const PROXY_SERVICE_URL = __ENV.PROXY_SERVICE_URL || 'http://localhost:8080';
const VU_IP_MAPPING_ENABLED = __ENV.VU_IP_MAPPING_ENABLED === 'true';

// IP rotation configuration
let proxyConfig = null;
let vuProxyMap = new Map();

// Setup function for IP rotation
export function setup() {
    console.log(`[VU ${__VU}] Setting up IP rotation test`);
    
    if (IP_ROTATION_ENABLED) {
        console.log(`[VU ${__VU}] IP rotation enabled with type: ${PROXY_TYPE}`);
        
        // Get proxy configuration for this VU
        proxyConfig = getProxyConfig(__VU);
        
        if (proxyConfig) {
            console.log(`[VU ${__VU}] Using proxy: ${proxyConfig.proxy}`);
            
            // Test proxy connectivity
            const testResponse = http.get('https://httpbin.org/ip', {
                proxy: proxyConfig.proxy,
                timeout: '10s'
            });
            
            if (testResponse.status === 200) {
                console.log(`[VU ${__VU}] Proxy test successful: ${testResponse.body}`);
                ip_rotation_success.add(1);
            } else {
                console.log(`[VU ${__VU}] Proxy test failed: ${testResponse.status}`);
                ip_rotation_success.add(0);
            }
        }
    } else {
        console.log(`[VU ${__VU}] IP rotation disabled`);
    }
    
    return { proxyConfig };
}

// Function to get proxy configuration
function getProxyConfig(vuId) {
    if (PROXY_TYPE === 'static') {
        return getStaticProxyConfig(vuId);
    } else if (PROXY_TYPE === 'rotating') {
        return getRotatingProxyConfig(vuId);
    } else if (PROXY_TYPE === 'tor') {
        return getTorProxyConfig();
    } else {
        return getStaticProxyConfig(vuId);
    }
}

// Static proxy configuration
function getStaticProxyConfig(vuId) {
    const proxyList = [
        'http://192.168.1.100:8080',
        'http://192.168.1.101:8080',
        'http://192.168.1.102:8080',
        'http://192.168.1.103:8080',
        'http://192.168.1.104:8080',
        'http://192.168.1.105:8080',
        'http://192.168.1.106:8080',
        'http://192.168.1.107:8080',
        'http://192.168.1.108:8080',
        'http://192.168.1.109:8080'
    ];
    
    const proxyIndex = vuId % proxyList.length;
    const proxy = proxyList[proxyIndex];
    
    return {
        proxy: proxy,
        type: 'static',
        vuId: vuId,
        proxyIndex: proxyIndex
    };
}

// Rotating proxy configuration
function getRotatingProxyConfig(vuId) {
    try {
        const response = http.get(`${PROXY_SERVICE_URL}/rotate?vu=${vuId}`, {
            timeout: '5s'
        });
        
        if (response.status === 200) {
            const data = JSON.parse(response.body);
            return {
                proxy: `http://${data.proxy_ip}`,
                type: 'rotating',
                vuId: vuId,
                proxyIp: data.proxy_ip,
                timestamp: data.timestamp
            };
        }
    } catch (error) {
        console.log(`[VU ${vuId}] Failed to get rotating proxy: ${error}`);
    }
    
    // Fallback to static proxy
    return getStaticProxyConfig(vuId);
}

// Tor proxy configuration
function getTorProxyConfig() {
    return {
        proxy: 'socks5://127.0.0.1:9050',
        type: 'tor',
        vuId: __VU
    };
}

// Main test function
export default function (data) {
    const options = {};
    
    // Configure proxy if IP rotation is enabled
    if (IP_ROTATION_ENABLED && data.proxyConfig) {
        options.proxy = data.proxyConfig.proxy;
        
        // Track unique IP usage
        if (VU_IP_MAPPING_ENABLED) {
            vuProxyMap.set(__VU, data.proxyConfig.proxy);
            unique_ips_used.add(1);
        }
    }
    
    // Add request headers to identify VU
    options.headers = {
        'User-Agent': `k6-load-test-vu-${__VU}`,
        'X-VU-ID': __VU.toString(),
        'X-Proxy-Type': data.proxyConfig ? data.proxyConfig.type : 'none'
    };
    
    // Make request to target
    const response = http.get(TARGET_URL, options);
    
    // Check response
    const checks = check(response, {
        'status is 200': (r) => r.status === 200,
        'response time < 2000ms': (r) => r.timings.duration < 2000,
        'proxy used': (r) => IP_ROTATION_ENABLED ? data.proxyConfig !== null : true,
        'unique IP used': (r) => VU_IP_MAPPING_ENABLED ? vuProxyMap.has(__VU) : true
    });
    
    // Log request details
    if (IP_ROTATION_ENABLED && data.proxyConfig) {
        console.log(`[VU ${__VU}] Request via ${data.proxyConfig.type} proxy: ${data.proxyConfig.proxy}`);
    }
    
    // Add sleep between requests
    sleep(1);
}

// Teardown function
export function teardown(data) {
    if (IP_ROTATION_ENABLED) {
        console.log(`[VU ${__VU}] Cleaning up IP rotation`);
        
        // Log final statistics
        if (VU_IP_MAPPING_ENABLED) {
            console.log(`[VU ${__VU}] Final proxy mapping: ${vuProxyMap.size} VUs with unique IPs`);
        }
    }
}

// Handle summary
export function handleSummary(data) {
    const summary = {
        'ip-rotation-summary.json': JSON.stringify({
            ip_rotation_enabled: IP_ROTATION_ENABLED,
            proxy_type: PROXY_TYPE,
            target_url: TARGET_URL,
            vu_count: data.metrics.vus ? data.metrics.vus.values.max : 0,
            ip_rotation_success_rate: data.metrics.ip_rotation_success ? data.metrics.ip_rotation_success.values.rate : 0,
            unique_ips_used: data.metrics.unique_ips_used ? data.metrics.unique_ips_used.values.rate : 0,
            proxy_assignments: Array.from(vuProxyMap.entries()),
            timestamp: new Date().toISOString()
        }, null, 2)
    };
    
    return summary;
} 