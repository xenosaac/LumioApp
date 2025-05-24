# Sleep Analysis Feature

This feature replaces the heart rate monitoring with sleep data analysis using HealthKit in iOS.

## Files Modified/Created

1. **SleepData.swift** (New): Core data model and manager for sleep analysis
   - Defines `SleepDataPoint` struct with start/end times and sleep stage
   - Implements `SleepStage` enum for the different sleep stages (in bed, asleep, awake, REM, etc.)
   - Creates `SleepManager` class that handles:
     - HealthKit authorization and data fetching
     - Data filtering, processing and statistics
     - Mock data generation for development

2. **SleepChartView.swift** (New): UI for displaying sleep data charts
   - Visualizes sleep stages as stacked bar charts
   - Shows sleep statistics like total sleep time, average sleep time, and sleep efficiency
   - Includes a time range selector (1 week or 1 month view)

3. **StatsView.swift** (Modified): Changed health stats display to focus on sleep
   - Updated to work with the SleepManager instead of HeartRateManager
   - Added UI for HealthKit authorization and status
   - Updated info section to display sleep-related information

4. **ContentView.swift** (Modified): Updated tab interface
   - Added SleepManager as environment object
   - Updated the "Stats" tab to "Sleep" with a bed icon

5. **RAApp.swift** (Modified): Replaced heart rate with sleep analysis
   - Removed WatchConnectivityManager
   - Added SleepManager and HealthKit permissions request

6. **Info.plist** (Created): Added HealthKit permissions
   - Added NSHealthShareUsageDescription
   - Set appropriate background modes

## Implementation Details

### Sleep Data Model
Sleep data consists of periods with start and end times, along with a sleep stage categorization. The app supports all the standard sleep stages tracked by HealthKit:
- In Bed (overall time in bed)
- Asleep (general sleep state)
- Deep Sleep
- REM Sleep
- Core Sleep
- Awake (brief periods of wakefulness)

### Data Visualization
Sleep data is visualized as stacked bar charts, with:
- Each day showing as a column
- Different sleep stages shown in different colors
- Duration measured in hours on the Y-axis

### Statistics
The app calculates and displays:
- Total Sleep Time: Sum of all sleep periods in the selected time range
- Average Sleep Time per Night: Average sleep duration per day
- Sleep Efficiency: Percentage of time in bed that was actually spent asleep

### HealthKit Integration
The app requests read-only permission to access sleep analysis data from the Health app. It can:
- Check authorization status
- Request permissions if not already granted
- Fetch sleep data for the selected time range
- Support fallback to mock data for development and demonstration

## Setup Requirements
To enable HealthKit integration:
1. Ensure the project has the HealthKit capability enabled in Xcode
2. The Info.plist includes the proper NSHealthShareUsageDescription key
3. The app properly requests permissions at runtime

Note: Sleep data will only be available if the user has sleep tracking configured on their iPhone or Apple Watch and has granted the app permission to access this data. 