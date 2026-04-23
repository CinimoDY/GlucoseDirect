---
name: sensor-debug
description: Configure VirtualConnection for specific glucose testing scenarios
disable-model-invocation: true
---

# Sensor Debug Skill

Configure the VirtualConnection simulator for testing specific glucose scenarios.

## File
`App/Modules/SensorConnector/VirtualConnection/VirtualConnection.swift`

## How VirtualConnection Works

The simulation oscillates glucose values using a direction (`.up`/`.down`) pattern:
- Moving UP: glucose increases by 0-11 mg/dL per interval until it exceeds `nextRotation` (random 160-240), then switches to DOWN
- Moving DOWN: glucose decreases by 0-11 mg/dL per interval until it drops below `nextRotation` (random 50-80), then switches to UP
- 5% chance of faulty readings with `.AVG_DELTA_EXCEEDED` quality
- Initial glucose: 100 mg/dL, sensor age starts at 120 min, warmup is 60 min

## Key State Variables to Modify

| Variable | Default | Purpose |
|----------|---------|---------|
| `nextGlucose` | 100 | Current glucose value |
| `direction` | `.up` | Trend direction (`.up` or `.down`) |
| `nextRotation` | 112 | Threshold to flip direction |
| `sensorInterval` | 60s | Reading interval |
| `initAge` / `age` | 120 | Sensor age in minutes |
| `warmupTime` | 60 | Warmup period |

## Testing Scenarios

### Persistent High Glucose
Set `nextGlucose = 250` and `nextRotation = 300` (high UP threshold so it stays high).

### Persistent Low Glucose
Set `nextGlucose = 55`, `direction = .down`, and `nextRotation = 40` (low DOWN threshold).

### Rapid Rise
Set `nextGlucose = 100`, `direction = .up`, `nextRotation = 300`. Increase the random delta range in `sendNextGlucose()` from `0..<11` to `0..<25`.

### Rapid Drop
Set `nextGlucose = 200`, `direction = .down`, `nextRotation = 40`. Increase delta range similarly.

### Sensor Warmup
Set `initAge = 0`, `age = 0` so the sensor starts in warmup state.

### Sensor Expiring
Set `initAge = 14 * 24 * 60 - 60` to test near-expiry behavior (1 hour remaining).

### High Error Rate
Change faulty reading threshold from `<= 5` to `<= 30` for 30% error rate.

## Notes

- VirtualConnection is only available in simulator builds (`#if targetEnvironment(simulator)`)
- Registered in `App.swift` with ID `DirectConfig.virtualID`
- After modifying, rebuild with `/build`
