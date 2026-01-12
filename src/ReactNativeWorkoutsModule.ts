import { NativeModule, requireNativeModule } from "expo";

import type {
  ActivityType,
  AuthorizationStatus,
  CustomWorkoutConfig,
  DateComponents,
  LocationType,
  PacerWorkoutConfig,
  ReactNativeWorkoutsModuleEvents,
  ScheduledWorkout,
  ScheduleResult,
  SingleGoalWorkoutConfig,
  SwimBikeRunWorkoutConfig,
  WorkoutPlan,
  WorkoutValidationResult,
} from "./ReactNativeWorkouts.types";

declare class ReactNativeWorkoutsModule
  extends NativeModule<ReactNativeWorkoutsModuleEvents> {
  // Constants
  /**
   * Whether Health data is available on this device.
   * On iOS simulators this is typically `false`.
   */
  readonly isAvailable: boolean;

  // Authorization
  /**
   * Returns the current WorkoutKit authorization status.
   */
  getAuthorizationStatus(): Promise<AuthorizationStatus>;
  /**
   * Prompts the user for WorkoutKit authorization (if needed).
   */
  requestAuthorization(): Promise<AuthorizationStatus>;

  // Validation
  /**
   * Returns whether a given goal type is supported for the provided activity + location.
   */
  supportsGoal(
    activityType: ActivityType,
    locationType: LocationType,
    goalType: string,
  ): Promise<boolean>;

  // Custom Workouts
  /**
   * Validates a custom workout config. (Legacy name: this does not persist anything.)
   */
  createCustomWorkout(
    config: CustomWorkoutConfig,
  ): Promise<WorkoutValidationResult>;
  /**
   * Previews a custom workout via Apple's system modal.
   */
  previewWorkout(config: CustomWorkoutConfig): Promise<boolean>;
  /**
   * Schedules a custom workout (syncs it to the Apple Watch Workout app).
   *
   * Prefer using `useCustomWorkout(...)` + `plan.scheduleAndSync(...)` for new code.
   */
  scheduleWorkout(
    config: CustomWorkoutConfig,
    date: DateComponents,
  ): Promise<ScheduleResult>;

  // Single Goal Workouts
  /**
   * Validates a single-goal workout config. (Legacy name: this does not persist anything.)
   */
  createSingleGoalWorkout(
    config: SingleGoalWorkoutConfig,
  ): Promise<WorkoutValidationResult>;
  /**
   * Previews a single-goal workout via Apple's system modal.
   */
  previewSingleGoalWorkout(config: SingleGoalWorkoutConfig): Promise<boolean>;
  /**
   * Schedules a single-goal workout (syncs it to the Apple Watch Workout app).
   *
   * Prefer using `useSingleGoalWorkout(...)` + `plan.scheduleAndSync(...)` for new code.
   */
  scheduleSingleGoalWorkout(
    config: SingleGoalWorkoutConfig,
    date: DateComponents,
  ): Promise<ScheduleResult>;

  // Pacer Workouts
  /**
   * Validates a pacer workout config. (Legacy name: this does not persist anything.)
   */
  createPacerWorkout(
    config: PacerWorkoutConfig,
  ): Promise<WorkoutValidationResult>;
  /**
   * Previews a pacer workout via Apple's system modal.
   */
  previewPacerWorkout(config: PacerWorkoutConfig): Promise<boolean>;
  /**
   * Schedules a pacer workout (syncs it to the Apple Watch Workout app).
   *
   * Prefer using `usePacerWorkout(...)` + `plan.scheduleAndSync(...)` for new code.
   */
  schedulePacerWorkout(
    config: PacerWorkoutConfig,
    date: DateComponents,
  ): Promise<ScheduleResult>;

  // Shared WorkoutPlan factories (object-oriented API)
  /**
   * Creates a stateful `WorkoutPlan` shared object (recommended API for new code).
   */
  createCustomWorkoutPlan(config: CustomWorkoutConfig): Promise<WorkoutPlan>;
  /**
   * Creates a stateful `WorkoutPlan` shared object (recommended API for new code).
   */
  createSingleGoalWorkoutPlan(
    config: SingleGoalWorkoutConfig,
  ): Promise<WorkoutPlan>;
  /**
   * Creates a stateful `WorkoutPlan` shared object (recommended API for new code).
   */
  createPacerWorkoutPlan(config: PacerWorkoutConfig): Promise<WorkoutPlan>;
  /**
   * Creates a stateful multisport `WorkoutPlan` shared object (recommended API for new code).
   */
  createSwimBikeRunWorkoutPlan(
    config: SwimBikeRunWorkoutConfig,
  ): Promise<WorkoutPlan>;

  // Scheduled Workouts Management
  /**
   * Lists scheduled workouts created by this app.
   */
  getScheduledWorkouts(): Promise<ScheduledWorkout[]>;
  /**
   * Removes a scheduled workout by ID.
   */
  removeScheduledWorkout(id: string): Promise<boolean>;
  /**
   * Removes all scheduled workouts created by this app.
   */
  removeAllScheduledWorkouts(): Promise<boolean>;

  // Utility
  getSupportedActivityTypes(): ActivityType[];
  getSupportedGoalTypes(): string[];
  getSupportedLocationTypes(): LocationType[];
}

export default requireNativeModule<ReactNativeWorkoutsModule>(
  "ReactNativeWorkouts",
);
