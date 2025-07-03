# Queue-it Integration Test Guide

## Overview
This document provides a comprehensive guide for running and interpreting Queue-it integration tests in the PURELY E-commerce application. It covers test cases, key metrics, Grafana dashboard usage, interpretation, test execution steps, expected results, and a section for actual results with screenshot references.

---

## 1. Test Cases

| Test Case ID | Description | Endpoint | Expected Result |
|--------------|-------------|----------|-----------------|
| TC-01 | Validate queue token | `/api/queueit/validate` | Returns queue status, redirect info, or queueId |
| TC-02 | Simulate queue user | `/api/queueit/queue` | Returns message or queue placement info |
| TC-03 | Cancel queue session | `/api/queueit/cancel` | Returns cancellation status and redirect info |
| TC-04 | Extend queue cookie | `/api/queueit/extend-cookie` | Returns confirmation of cookie extension |
| TC-05 | Get queue/event status | `/api/queueit/status` | Returns current status of Queue-it integration |
| TC-06 | Health check | `/api/queueit/health` | Returns health status of Queue-it integration |
| TC-07 | Simulate event (stub) | `/api/queueit/simulate-event` | Returns 501 Not Implemented (for future use) |
| TC-08 | Inspect session info (stub) | `/api/queueit/session-info` | Returns 501 Not Implemented (for future use) |
| TC-09 | Reset test state (stub) | `/api/queueit/reset-test-state` | Returns 501 Not Implemented (for future use) |

---

## 2. Key Metrics & Grafana Dashboard

### Metrics Tracked
- **queue_overlay_shown_total**: Number of times the Queue-it overlay is shown
- **queue_join_total**: Number of users joining the queue
- **queue_cancel_total**: Number of queue cancellations
- **queue_error_total**: Number of queue-related errors
- **queue_status_check_total**: Number of status checks performed
- **rate(queue_error_total[5m])**: Error rate over time
- **sum by(eventId, status) (rate(queue_join_total[5m]))**: Queue joins breakdown by event and status

### Where to Find in Grafana
- **Dashboard**: `Queue-it Integration Dashboard`
- **Panels**:
  - *Queue Overlay Shown*: Top left
  - *Queue Join Events*: Top center
  - *Queue Cancel Events*: Middle left
  - *Queue Errors*: Middle center
  - *Queue Status Checks*: Bottom left
  - *Integration Errors Over Time*: Below main stats, time series
  - *Queue Joins by Event ID and Status*: Bottom, time series breakdown

### How to Interprete
- **Overlay Shown**: High value indicates frequent queueing; should increase when tests trigger overlays.
- **Join/Cancel Events**: Should increment as users join/cancel queues during tests.
- **Errors**: Should remain low; spikes indicate integration or logic issues.
- **Status Checks**: Should increment with each status API call.
- **Error Rate Over Time**: Spikes indicate periods of instability or failed tests.
- **Breakdown by Event/Status**: Helps identify which events or statuses are most active or problematic.

---

## 3. Steps to Run Test Cases

1. **Ensure all services are running** (API Gateway, Nginx, Prometheus, Grafana, etc.).
2. **Rebuild and redeploy the frontend** to include the integration test UI.
3. **Access the integration test UI** (QueueItIntegrationTest component) in your app.
4. **Run each test case** by filling in the required fields and submitting the form.
5. **Observe the response** in the UI and check the corresponding metrics in Grafana.
6. **Take screenshots** of the Grafana panels after each test for documentation.

---

## 4. Expected Results

| Test Case ID | Expected Result |
|--------------|----------------|
| TC-01 | Valid token: queueId returned; Invalid token: error or redirect |
| TC-02 | Message confirming queue placement (or stub message) |
| TC-03 | Confirmation of queue cancellation and redirect info |
| TC-04 | Confirmation of cookie extension |
| TC-05 | Status message with timestamp |
| TC-06 | Health status with service info |
| TC-07 | 501 Not Implemented |
| TC-08 | 501 Not Implemented |
| TC-09 | 501 Not Implemented |

---

## 5. Actual Results & Screenshots

| Test Case ID | Actual Result | Screenshot Reference |
|--------------|--------------|---------------------|
| TC-01 |  | ![TC-01](screenshots/TC-01.png) |
| TC-02 |  | ![TC-02](screenshots/TC-02.png) |
| TC-03 |  | ![TC-03](screenshots/TC-03.png) |
| TC-04 |  | ![TC-04](screenshots/TC-04.png) |
| TC-05 |  | ![TC-05](screenshots/TC-05.png) |
| TC-06 |  | ![TC-06](screenshots/TC-06.png) |
| TC-07 |  | ![TC-07](screenshots/TC-07.png) |
| TC-08 |  | ![TC-08](screenshots/TC-08.png) |
| TC-09 |  | ![TC-09](screenshots/TC-09.png) |

> **Tip:** Save screenshots in a `screenshots/` folder next to this document for easy reference.

---

## 6. Notes
- Only use the integration test UI and endpoints for non-production/testing environments.
- Update this document with actual results and screenshots after each test run.
- For advanced troubleshooting, consult backend logs and Prometheus queries directly. 