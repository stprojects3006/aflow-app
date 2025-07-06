# Video Script: Queue-it Max Capacity Analysis with Grafana Visualization

## Video Title: "Determining Queue-it Max Queue Capacity: CSV Results vs Grafana Visualization"

## Duration: 8-10 minutes

---

## Opening (0:00 - 0:30)
**Visual**: Title screen with Queue-it logo and "Max Capacity Analysis"

**Narration**: 
"Welcome to our Queue-it max capacity analysis. Today we'll show you how to determine the maximum number of users that can be queued simultaneously, and how to validate our findings using both automated test results and real-time Grafana visualizations."

---

## Section 1: Overview of the Problem (0:30 - 1:30)
**Visual**: Split screen showing:
- Left: Queue-it waiting room concept
- Right: High traffic scenario

**Narration**:
"Queue-it protects your application by placing users in a waiting room when traffic exceeds your threshold. But what happens when the queue itself reaches its maximum capacity? At what point does Queue-it stop accepting new users into the queue? This is crucial for capacity planning and understanding your system's limits."

**Key Points to Highlight**:
- Queue-it doesn't reject users, it queues them
- There's a maximum queue size limit
- We need to find this limit for capacity planning

---

## Section 2: Automated Testing Approach (1:30 - 2:30)
**Visual**: Show the automated script and explain the methodology

**Narration**:
"We've created an automated script that ramps up load from 100 to 20,000 virtual users, testing each level for one minute. This gives us systematic data about when the queue reaches its limits."

**Show on Screen**:
```bash
./find-queueit-max-capacity.sh
```

**Explain the VU levels**: 100, 500, 1000, 2000, 5000, 10000, 20000

---

## Section 3: CSV Results Analysis (2:30 - 4:00)
**Visual**: Open the CSV file and analyze the results

**Narration**:
"Let's examine our automated test results. The CSV file shows us three key metrics for each virtual user level: redirects, successes, and errors."

**Show CSV Structure**:
```
VUs,Redirects,Successes,Errors,Notes
100,95,5,0,
500,480,20,0,
1000,950,50,0,
2000,1800,200,0,
5000,4000,1000,0,
10000,8000,1500,500,"Possible queue full"
20000,8000,1000,11000,"Queue full - errors detected"
```

**Key Analysis Points**:
- **Normal Operation**: High redirects, low successes, zero errors
- **Queue Approaching Full**: Redirects plateau, errors start appearing
- **Queue Full**: Redirects drop, errors spike significantly

**Identify the Tipping Point**: "Notice how at 10,000 VUs, we start seeing errors, and at 20,000 VUs, the error rate explodes. This suggests our max queue capacity is around 8,000-10,000 users."

---

## Section 4: Grafana Dashboard Validation (4:00 - 6:00)
**Visual**: Switch to Grafana dashboard and show real-time correlation

**Narration**:
"Now let's validate these findings using our Grafana dashboard. The real-time visualizations will confirm our CSV analysis and show us exactly what happens when we hit the queue limits."

**Dashboard Navigation**:
1. **Open Grafana**: http://localhost:3000
2. **Navigate to**: "Queue-it Load Testing" dashboard
3. **Focus on**: K6 panels at the bottom

**Key Panels to Highlight**:

### Panel 1: K6 Queue-it Redirects
**Narration**: "This panel shows the rate of redirects to Queue-it per second. Watch how it behaves during our capacity tests."

**What to Look For**:
- Steady increase with load (normal operation)
- Plateau when approaching capacity
- Drop when queue is full

### Panel 2: K6 Successful Responses
**Narration**: "This shows requests that bypass the queue and are served directly. Notice the inverse relationship with redirects."

### Panel 3: Test Response Times
**Narration**: "Response times can also indicate queue capacity issues. When the queue is full, response times may spike due to error handling."

---

## Section 5: Real-Time Test Demonstration (6:00 - 7:30)
**Visual**: Run a live test while showing Grafana dashboard

**Narration**:
"Let's run a live test to see this in action. We'll start with a moderate load and gradually increase it to demonstrate the queue capacity limits."

**Live Test Commands**:
```bash
# Start with moderate load
k6 run --vus 1000 --duration 2m k6-load-test.js

# Then increase to capacity limit
k6 run --vus 10000 --duration 2m k6-load-test.js
```

**What to Show During Test**:
- Grafana panels updating in real-time
- Correlation between VU count and redirect rates
- Point where redirects plateau or drop
- Error rate spikes when capacity is exceeded

---

## Section 6: Correlation Analysis (7:30 - 8:30)
**Visual**: Side-by-side comparison of CSV data and Grafana charts

**Narration**:
"Let's correlate our CSV results with the Grafana visualizations to confirm our findings."

**Correlation Points**:
1. **CSV shows 8,000 redirects at 10,000 VUs**
2. **Grafana shows redirect rate plateauing at the same point**
3. **Both show error spikes when capacity is exceeded**

**Key Insight**: "The CSV gives us the numbers, but Grafana shows us the patterns and timing. Together, they provide a complete picture of our queue capacity."

---

## Section 7: Conclusions and Recommendations (8:30 - 9:30)
**Visual**: Summary slide with key findings

**Narration**:
"Based on our analysis, we've determined that our Queue-it max queue capacity is approximately 8,000-10,000 concurrent users."

**Key Findings**:
- **Max Queue Capacity**: 8,000-10,000 users
- **Tipping Point**: 10,000 VUs (errors start appearing)
- **Full Capacity**: 20,000 VUs (significant error rate)

**Recommendations**:
1. **Monitor queue size** during peak traffic
2. **Set up alerts** when approaching 80% of capacity
3. **Plan for capacity increases** if needed
4. **Use this data** for infrastructure planning

---

## Closing (9:30 - 10:00)
**Visual**: Final slide with resources and next steps

**Narration**:
"This systematic approach to determining Queue-it max capacity helps you make informed decisions about your infrastructure and capacity planning. The combination of automated testing and real-time visualization gives you confidence in your findings."

**Resources Mentioned**:
- Automated test script: `find-queueit-max-capacity.sh`
- Grafana dashboard: Queue-it Load Testing
- CSV results for detailed analysis

**Call to Action**: "Use these tools to analyze your own Queue-it implementation and ensure you're prepared for peak traffic scenarios."

---

## Technical Notes for Recording:

### Screen Layout Suggestions:
- **Main View**: Grafana dashboard
- **Picture-in-Picture**: Terminal running K6 tests
- **Overlay**: CSV data when discussing results

### Key Transitions:
1. CSV analysis → Grafana validation
2. Static data → Live test demonstration
3. Individual metrics → Correlation analysis

### Important Visual Elements:
- Highlight the "K6 Queue-it Redirects" panel prominently
- Show the correlation between VU count and redirect rates
- Point out the exact moment when errors start appearing
- Use arrows or circles to highlight key data points

### Audio Cues:
- "Notice how..." when pointing out patterns
- "This is significant because..." when explaining findings
- "Let's validate this..." when switching to Grafana 