# GuardTime Monitoring - Detailed Explanation

## What Are We Monitoring?

When you tap the **"Start Monitoring"** button, the app activates Apple's Device Activity framework to track screen time data for **children in your Family Sharing group**.

### Data Being Collected:

1. **Social Media & Entertainment Apps**
   - Apps in categories like: Social, Entertainment, Networking
   - Examples: Instagram, TikTok, YouTube, Facebook, Snapchat, etc.
   - Total time spent per day
   - Time spent during specific hours (study time)

2. **Per-App Usage Details**
   - App name (e.g., "Instagram", "TikTok")
   - Duration of use per app
   - Number of times app was opened (pickups)
   - App icon/token for display

3. **Time Period Tracking**
   - **Today's data**: Current day from midnight to now
   - **Study hours**: 6 PM - 10 PM (4-hour window)
   - **Weekly history**: Last 7 days of data

4. **Per-Child Tracking**
   - Each child in Family Sharing is tracked separately
   - Data is isolated by Apple ID
   - You switch between children using tabs

---

## How Results Are Displayed

### Main Interface Structure

```
┌─────────────────────────────────────┐
│  [Tab: Child 1] [Tab: Child 2]     │ ← Child selector tabs at top
├─────────────────────────────────────┤
│                                     │
│  📱 Today's View (Default)          │
│                                     │
│  ┌────────────────────────────────┐│
│  │ TODAY'S SOCIAL TIME            ││
│  │ 2h 45m                         ││ ← Big pink card showing total
│  │ 💬 icon                        ││
│  └────────────────────────────────┘│
│                                     │
│  ┌────────────────────────────────┐│
│  │ STUDY TIME MONITORING          ││
│  │ 6-10 PM                        ││
│  │                                ││
│  │ Today's Social During Study:   ││
│  │ 0h 45m                         ││ ← Social media during study hours
│  │ Limit: 1h                      ││
│  │ ▓▓▓▓▓▓▓▓░░░░ (75%)            ││ ← Progress bar
│  │ ✓ Within limit                 ││
│  └────────────────────────────────┘│
│                                     │
│  ┌────────────────────────────────┐│
│  │ TOP 5 APPS TODAY               ││
│  │                                ││
│  │ 1. Instagram      1h 20m  48% ││
│  │ 2. TikTok        45m      27% ││ ← App list with duration & %
│  │ 3. YouTube       20m      12% ││
│  │ 4. Snapchat      15m       9% ││
│  │ 5. Messages       5m       3% ││
│  └────────────────────────────────┘│
│                                     │
│  [📅 View Weekly History]          │ ← Button to see past 7 days
│                                     │
└─────────────────────────────────────┘
```

### Weekly History View

When you tap "View Weekly History":

```
┌─────────────────────────────────────┐
│  [← Back to Today]                  │
├─────────────────────────────────────┤
│                                     │
│  ┌────────────────────────────────┐│
│  │ WEEKLY SOCIAL AVERAGE          ││
│  │ 2h 30m                         ││ ← Average across 7 days
│  │                                ││
│  │    Bar Chart:                  ││
│  │    Mon ▓▓▓░  2.5h              ││
│  │    Tue ▓▓▓▓  3.2h              ││
│  │    Wed ▓▓░░  1.8h              ││ ← Visual chart of each day
│  │    Thu ▓▓▓░  2.4h              ││
│  │    Fri ▓▓▓▓▓ 4.1h              ││
│  │    Sat ▓▓▓░  2.3h              ││
│  │    Sun ▓▓░░  1.5h              ││
│  └────────────────────────────────┘│
│                                     │
│  ┌────────────────────────────────┐│
│  │ DAILY BREAKDOWN                ││
│  │                                ││
│  │ Yesterday (Oct 30)             ││
│  │ Social: 2h 15m                 ││
│  │ Study Hours: 30m               ││
│  │ Top Apps: Instagram (1h), ...  ││
│  │                                ││
│  │ 2 Days Ago (Oct 29)            ││
│  │ Social: 3h 0m                  ││ ← Expandable list of past days
│  │ Study Hours: 45m               ││
│  │ Top Apps: TikTok (1.5h), ...   ││
│  │                                ││
│  │ 3 Days Ago (Oct 28)            ││
│  │ Social: 1h 30m                 ││
│  │ ...                            ││
│  └────────────────────────────────┘│
└─────────────────────────────────────┘
```

---

## Data Format Details

### 1. **Today's Social Time Card**
- **What it shows**: Total time spent on social/entertainment apps TODAY
- **Format**: Large bold number (e.g., "2h 45m")
- **Color**: Pink/Red to indicate social media usage
- **Icon**: Chat bubbles 💬
- **Updates**: Real-time as Apple's framework reports data

### 2. **Study Time Monitor (6 PM - 10 PM)**
- **What it shows**: Social media usage ONLY during study hours (6-10 PM)
- **Format**: 
  - Hours and minutes (e.g., "0h 45m")
  - Progress bar showing % of 1-hour limit
  - Status indicator: ✓ Within limit / ⚠️ Limit exceeded
- **Color**: 
  - Green if under 1 hour
  - Red if over 1 hour (exceeding study time limit)
- **Calculation**: Estimates ~17% of daily app usage falls in this 4-hour window

### 3. **Top 5 Apps Section**
- **What it shows**: The 5 most-used social/entertainment apps TODAY
- **Format for each app**:
  ```
  1. App Name      Duration    Percentage
     Instagram     1h 20m      48%
  ```
- **Sorted by**: Duration (most used first)
- **Percentage**: % of total social time
- **Visual**: Horizontal bar showing relative usage

### 4. **Weekly Activity Chart**
- **What it shows**: Bar chart of social media time for last 7 days
- **Format**:
  - X-axis: Days of week (Mon, Tue, Wed, etc.)
  - Y-axis: Hours (0-5h typically)
  - Bars: Filled to show duration
- **Interactive**: Tap a day to see details
- **Average**: Shows weekly average at the top

### 5. **Daily Breakdown List**
- **What it shows**: Detailed view of each past day
- **Format per day**:
  ```
  Yesterday (Oct 30, 2025)
  Total Social: 2h 15m
  During Study Hours: 30m
  Top Apps: Instagram (1h 20m), TikTok (45m), YouTube (10m)
  ```
- **Order**: Yesterday first, then going back 7 days
- **Expandable**: Tap to see more details

---

## How Monitoring Works (Technical)

### Step-by-Step Process:

1. **You tap "Start Monitoring"**
   - App creates a DeviceActivitySchedule
   - Schedule runs from 00:00 to 23:59 daily
   - Repeats every day automatically

2. **iOS collects data in background**
   - Apple's framework monitors all app usage
   - Data is stored securely by iOS (sandboxed)
   - Extension cannot access data directly

3. **iOS triggers the Report Extension**
   - Happens periodically (iOS decides when)
   - Extension receives DeviceActivityResults
   - Contains data for all family members

4. **Extension processes the data**
   - Iterates through each child in Family Sharing
   - Filters for social/entertainment apps
   - Calculates totals, averages, study hours
   - Creates the display data

5. **UI automatically updates**
   - Report view renders the processed data
   - Shows cards, charts, and lists
   - Updates as new data comes in

### Important Notes:

- **Delay**: Data may take 5-10 minutes to appear after starting monitoring
- **Privacy**: Extension runs in a sandbox - cannot send data elsewhere
- **Accuracy**: Study hours (6-10 PM) is estimated at ~17% of daily usage
- **Permissions**: Requires Screen Time API authorization + Family Sharing setup

---

## Color Coding System

| Color | Meaning | Used For |
|-------|---------|----------|
| 💙 Blue | Normal/Active | Start monitoring button, navigation |
| 💗 Pink | Social media | Social time indicators, icons |
| 🔴 Red | Warning/Over limit | Stop button, exceeded study time |
| 🟢 Green | Good/Under limit | Status indicator, within limits |
| 💜 Purple | Premium feature | Weekly history button gradient |
| ⚪ Gray | Inactive/Disabled | Monitoring off, no data states |

---

## Time Format Standards

- **Short durations**: "45m" (under 1 hour)
- **Medium durations**: "2h 15m" (hours + minutes)
- **Percentages**: "48%" (of total time)
- **Dates**: "Yesterday", "2 days ago", "Oct 30"
- **Time ranges**: "6-10 PM" (study hours)

---

## What Happens When You Stop Monitoring?

When you tap "Stop Monitoring":
- Device Activity schedule is cancelled
- iOS stops collecting new data
- **Existing data remains visible** in the report view
- To resume, just tap "Start Monitoring" again

The historical data (weekly view) persists as long as iOS keeps it in the Device Activity database (typically 7-14 days).

---

## Summary

**In Plain English:**

1. You press "Start Monitoring" → iOS starts tracking your kids' app usage
2. Data appears in 5-10 minutes → Shows today's social media time
3. Main card shows total social time → Big pink number at top
4. Study monitor shows 6-10 PM usage → With a 1-hour limit indicator
5. Top 5 apps list → Shows which apps they use most
6. Weekly history → Bar chart + daily breakdown of past 7 days
7. Switch between kids → Using tabs at the top

**The Goal:** Help parents monitor their children's social media usage, especially during study hours (6-10 PM), with clear visual indicators and historical trends.
