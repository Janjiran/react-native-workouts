import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import ReactNativeWorkouts from "./ReactNativeWorkoutsModule";
import type {
    AuthorizationStatus,
    CustomWorkoutConfig,
    DateComponents,
    PacerWorkoutConfig,
    ScheduledWorkout,
    SingleGoalWorkoutConfig,
    SwimBikeRunWorkoutConfig,
    WorkoutPlan,
} from "./ReactNativeWorkouts.types";

type UseWorkoutPlanResult = {
    /**
     * A stateful `WorkoutPlan` shared object, or `null` when config is null/invalid.
     */
    plan: WorkoutPlan | null;
    /**
     * `true` while the hook is (re)creating the plan in native.
     */
    isLoading: boolean;
    /**
     * Any error that occurred while creating the plan.
     */
    error: Error | null;
};

function useWorkoutPlan<TConfig>(
    config: TConfig | null | undefined,
    createPlan: (config: TConfig) => Promise<WorkoutPlan>,
): UseWorkoutPlanResult {
    const [plan, setPlan] = useState<WorkoutPlan | null>(null);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<Error | null>(null);
    const planRef = useRef<WorkoutPlan | null>(null);

    // We want to recreate the plan when the config meaningfully changes.
    // Consumers should keep config stable (useMemo) for best results.
    const configKey = useMemo(() => JSON.stringify(config ?? null), [config]);

    useEffect(() => {
        let cancelled = false;

        const run = async () => {
            if (!config) {
                setPlan(null);
                planRef.current?.release();
                planRef.current = null;
                setError(null);
                setIsLoading(false);
                return;
            }

            setIsLoading(true);
            setError(null);

            try {
                const nextPlan = await createPlan(config);
                if (cancelled) {
                    // If the effect already cleaned up, ensure we don't leak the native object.
                    nextPlan.release();
                    return;
                }

                planRef.current?.release();
                planRef.current = nextPlan;
                setPlan(nextPlan);
            } catch (e) {
                if (!cancelled) {
                    setPlan(null);
                    planRef.current?.release();
                    planRef.current = null;
                    setError(e instanceof Error ? e : new Error(String(e)));
                }
            } finally {
                if (!cancelled) {
                    setIsLoading(false);
                }
            }
        };

        void run();

        return () => {
            cancelled = true;
            planRef.current?.release();
            planRef.current = null;
        };
    }, [configKey, createPlan]);

    return { plan, isLoading, error };
}

export function useCustomWorkout(
    config: CustomWorkoutConfig | null,
): UseWorkoutPlanResult {
    return useWorkoutPlan(config, ReactNativeWorkouts.createCustomWorkoutPlan);
}

export function useSingleGoalWorkout(
    config: SingleGoalWorkoutConfig | null,
): UseWorkoutPlanResult {
    return useWorkoutPlan(
        config,
        ReactNativeWorkouts.createSingleGoalWorkoutPlan,
    );
}

export function usePacerWorkout(
    config: PacerWorkoutConfig | null,
): UseWorkoutPlanResult {
    return useWorkoutPlan(config, ReactNativeWorkouts.createPacerWorkoutPlan);
}

export function useSwimBikeRunWorkout(
    config: SwimBikeRunWorkoutConfig | null,
): UseWorkoutPlanResult {
    return useWorkoutPlan(
        config,
        ReactNativeWorkouts.createSwimBikeRunWorkoutPlan,
    );
}

export type UseWorkoutAuthorizationResult = {
    /**
     * Current authorization status (fetched on mount).
     */
    status: AuthorizationStatus | null;
    isLoading: boolean;
    error: Error | null;
    /**
     * Re-reads the authorization status.
     */
    refresh: () => Promise<AuthorizationStatus>;
    /**
     * Prompts for authorization (if needed) and returns the new status.
     */
    request: () => Promise<AuthorizationStatus>;
};

/**
 * Hook to read/request WorkoutKit authorization.
 */
export function useWorkoutAuthorization(): UseWorkoutAuthorizationResult {
    const [status, setStatus] = useState<AuthorizationStatus | null>(null);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<Error | null>(null);

    const refresh = useCallback(async () => {
        setIsLoading(true);
        setError(null);
        try {
            const next = await ReactNativeWorkouts.getAuthorizationStatus();
            setStatus(next);
            return next;
        } catch (e) {
            const err = e instanceof Error ? e : new Error(String(e));
            setError(err);
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, []);

    const request = useCallback(async () => {
        setIsLoading(true);
        setError(null);
        try {
            const next = await ReactNativeWorkouts.requestAuthorization();
            setStatus(next);
            return next;
        } catch (e) {
            const err = e instanceof Error ? e : new Error(String(e));
            setError(err);
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, []);

    useEffect(() => {
        void refresh();
    }, [refresh]);

    return { status, isLoading, error, refresh, request };
}

export type UseScheduledWorkoutsResult = {
    workouts: ScheduledWorkout[];
    isLoading: boolean;
    error: Error | null;
    /**
     * Reloads scheduled workouts from native.
     */
    reload: () => Promise<ScheduledWorkout[]>;
    /**
     * Removes all scheduled workouts created by this app.
     */
    removeAll: () => Promise<void>;
    /**
     * Removes a single scheduled workout by ID.
     */
    remove: (id: string) => Promise<void>;
    /**
     * Schedules (syncs) a plan for the given date components, then reloads the list.
     *
     * Under the hood this calls `plan.scheduleAndSync(date)`.
     */
    schedule: (
        plan: WorkoutPlan,
        date: DateComponents,
    ) => Promise<{ id: string }>;
};

/**
 * Hook to manage scheduled workouts.
 */
export function useScheduledWorkouts(): UseScheduledWorkoutsResult {
    const [workouts, setWorkouts] = useState<ScheduledWorkout[]>([]);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<Error | null>(null);

    const reload = useCallback(async () => {
        setIsLoading(true);
        setError(null);
        try {
            const next = await ReactNativeWorkouts.getScheduledWorkouts();
            setWorkouts(next);
            return next;
        } catch (e) {
            const err = e instanceof Error ? e : new Error(String(e));
            setError(err);
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, []);

    const removeAll = useCallback(async () => {
        setIsLoading(true);
        setError(null);
        try {
            await ReactNativeWorkouts.removeAllScheduledWorkouts();
            setWorkouts([]);
        } catch (e) {
            const err = e instanceof Error ? e : new Error(String(e));
            setError(err);
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, []);

    const remove = useCallback(async (id: string) => {
        setIsLoading(true);
        setError(null);
        try {
            await ReactNativeWorkouts.removeScheduledWorkout(id);
            setWorkouts((prev) => prev.filter((w) => w.id !== id));
        } catch (e) {
            const err = e instanceof Error ? e : new Error(String(e));
            setError(err);
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, []);

    const schedule = useCallback(
        async (plan: WorkoutPlan, date: DateComponents) => {
            setIsLoading(true);
            setError(null);
            try {
                 const result = await plan.scheduleAndSync(date);
                await reload();
                return { id: result.id };
            } catch (e) {
                const err = e instanceof Error ? e : new Error(String(e));
                setError(err);
                throw err;
            } finally {
                setIsLoading(false);
            }
        },
        [reload],
    );

    useEffect(() => {
        void reload();
    }, [reload]);

    return { workouts, isLoading, error, reload, removeAll, remove, schedule };
}
