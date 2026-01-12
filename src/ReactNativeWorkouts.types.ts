/**
 * WorkoutKit authorization state as seen by Apple's `WorkoutScheduler`.
 */

export type AuthorizationStatus =
  | "authorized"
  | "notDetermined"
  | "denied"
  | "unknown";

// Shared Objects

import type { SharedObject } from "expo";

// Activity Types

/**
 * Supported workout activity types exposed by this package.
 *
 * Note: these map to HealthKit `HKWorkoutActivityType` values.
 */
export type ActivityType =
  | "running"
  | "cycling"
  | "walking"
  | "hiking"
  | "swimming"
  | "rowing"
  | "elliptical"
  | "stairClimbing"
  | "highIntensityIntervalTraining"
  | "yoga"
  | "functionalStrengthTraining"
  | "traditionalStrengthTraining"
  | "dance"
  | "jumpRope"
  | "coreTraining"
  | "pilates"
  | "kickboxing"
  | "stairs"
  | "stepTraining"
  | "wheelchairRunPace"
  | "wheelchairWalkPace";

export type LocationType = "indoor" | "outdoor";

// Units

export type DistanceUnit =
  | "meters"
  | "m"
  | "kilometers"
  | "km"
  | "miles"
  | "mi"
  | "yards"
  | "yd"
  | "feet"
  | "ft";

export type TimeUnit =
  | "seconds"
  | "s"
  | "sec"
  | "minutes"
  | "min"
  | "hours"
  | "h"
  | "hr";

export type EnergyUnit =
  | "kilocalories"
  | "kcal"
  | "cal"
  | "kilojoules"
  | "kj";

export type SpeedUnit =
  | "metersPerSecond"
  | "mps"
  | "m/s"
  | "kilometersPerHour"
  | "kph"
  | "km/h"
  | "milesPerHour"
  | "mph";

export type PaceUnit =
  | "minutesPerKilometer"
  | "min/km"
  | "minutesPerMile"
  | "min/mi";

// Goals

export interface OpenGoal {
  type: "open";
}

export interface DistanceGoal {
  type: "distance";
  value: number;
  unit?: DistanceUnit;
}

export interface TimeGoal {
  type: "time";
  value: number;
  unit?: TimeUnit;
}

export interface EnergyGoal {
  type: "energy";
  value: number;
  unit?: EnergyUnit;
}

export type WorkoutGoal = OpenGoal | DistanceGoal | TimeGoal | EnergyGoal;

// Alerts

export interface HeartRateZoneAlert {
  type: "heartRate";
  zone: number;
}

export interface HeartRateRangeAlert {
  type: "heartRate";
  min: number;
  max: number;
}

export interface PaceAlert {
  type: "pace";
  min: number;
  max: number;
  unit?: PaceUnit;
}

export interface SpeedAlert {
  type: "speed";
  min: number;
  max: number;
  unit?: SpeedUnit;
}

export interface CadenceAlert {
  type: "cadence";
  min: number;
  max: number;
}

export interface PowerAlert {
  type: "power";
  min: number;
  max: number;
}

export type WorkoutAlert =
  | HeartRateZoneAlert
  | HeartRateRangeAlert
  | PaceAlert
  | SpeedAlert
  | CadenceAlert
  | PowerAlert;

// Workout Steps

export type StepPurpose = "work" | "recovery";

export interface WorkoutStep {
  goal?: WorkoutGoal;
  alert?: WorkoutAlert;
}

export interface IntervalStep {
  purpose: StepPurpose;
  goal?: WorkoutGoal;
  alert?: WorkoutAlert;
}

export interface IntervalBlock {
  iterations?: number;
  steps: IntervalStep[];
}

// Workout Configurations

export interface CustomWorkoutConfig {
  /**
   * Activity type (running, cycling, etc).
   */
  activityType: ActivityType;
  /**
   * Indoor/outdoor (where applicable). Defaults to `"outdoor"` when omitted.
   */
  locationType?: LocationType;
  /**
   * Display name used by the system (where supported by WorkoutKit).
   */
  displayName?: string;
  warmup?: WorkoutStep;
  blocks: IntervalBlock[];
  cooldown?: WorkoutStep;
}

export interface SingleGoalWorkoutConfig {
  activityType: ActivityType;
  locationType?: LocationType;
  /**
   * Optional label for your app/back-end. WorkoutKit may not display this for all workout kinds.
   */
  displayName?: string;
  goal: WorkoutGoal;
}

export interface PacerTarget {
  type: "speed" | "pace";
  value: number;
  unit?: SpeedUnit | PaceUnit;
}

export interface PacerWorkoutConfig {
  activityType: ActivityType;
  locationType?: LocationType;
  /**
   * Optional label for your app/back-end. WorkoutKit may not display this for all workout kinds.
   */
  displayName?: string;
  target: PacerTarget;
}

export type SwimBikeRunActivityType = "swimming" | "cycling" | "running";

export interface SwimBikeRunActivityConfig {
  type: SwimBikeRunActivityType;
  /**
   * For running/cycling: `"indoor" | "outdoor"`.
   * For swimming: `"indoor"` means pool, `"outdoor"` means open water.
   */
  locationType?: LocationType;
}

export interface SwimBikeRunWorkoutConfig {
  /**
   * Display name shown by the system for multisport workouts.
   */
  displayName?: string;
  /**
   * Ordered list of activities (e.g. swim -> bike -> run).
   */
  activities: SwimBikeRunActivityConfig[];
}

// Date Components

export interface DateComponents {
  year?: number;
  month?: number;
  day?: number;
  hour?: number;
  minute?: number;
}

// Results

export interface WorkoutValidationResult {
  valid: boolean;
  displayName: string;
}

export interface ScheduleResult {
  success: boolean;
  id: string;
}

export interface ScheduledWorkout {
  id: string;
  date: DateComponents;
}

// Module Events

export interface AuthorizationChangeEvent {
  status: AuthorizationStatus;
}

export type ReactNativeWorkoutsModuleEvents = {
  onAuthorizationChange: (event: AuthorizationChangeEvent) => void;
};

export type WorkoutPlanKind = "custom" | "singleGoal" | "pacer" | "swimBikeRun";

export interface WorkoutPlanExport {
  /**
   * UUID of the underlying `WorkoutPlan` instance.
   *
   * This is useful for debugging/logging and for matching the ID returned by `plan.scheduleAndSync`.
   */
  id: string;
  kind: WorkoutPlanKind;
  /**
   * The original config used to create the plan.
   *
   * Use this to persist/share the plan in your own backend and recreate the plan later.
   */
  config: unknown;
}

export declare class WorkoutPlan extends SharedObject<{}> {
  /**
   * UUID of this plan instance.
   */
  readonly id: string;
  /**
   * Which kind of workout this plan represents.
   */
  readonly kind: WorkoutPlanKind;

  /**
   * Shows Apple's system Workout preview modal (includes “Add to Watch / Send to Watch” UX).
   */
  preview(): Promise<boolean>;

  /**
   * Schedules the plan using Apple's `WorkoutScheduler`.
   *
   * This is the mechanism that syncs the plan to the Apple Watch Workout app.
   */
  scheduleAndSync(date: DateComponents): Promise<ScheduleResult>;

  /**
   * Returns `{ id, kind, config }` for storing/sharing the plan in your own backend.
   *
   * This does NOT export a system-importable file — it's a JSON payload you can use to recreate
   * the plan via the `create*WorkoutPlan(...)` factories.
   */
  export(): WorkoutPlanExport;
}
