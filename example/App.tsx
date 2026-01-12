import { useMemo } from "react";
import type {
  AuthorizationStatus,
  PacerWorkoutConfig,
  CustomWorkoutConfig,
  SingleGoalWorkoutConfig,
  SwimBikeRunWorkoutConfig,
} from "react-native-workouts";
import {
  useCustomWorkout,
  usePacerWorkout,
  useSingleGoalWorkout,
  useSwimBikeRunWorkout,
  useScheduledWorkouts,
  useWorkoutAuthorization,
} from "../src/hooks";
import {
  Alert,
  Button,
  Platform,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";

export default function App() {
  const ensureIOS = () => {
    if (Platform.OS !== "ios") {
      Alert.alert("Not supported", "WorkoutKit is only available on iOS.");
      return false;
    }
    return true;
  };

  const buildSampleCustomWorkout = (): CustomWorkoutConfig => ({
    activityType: "running",
    locationType: "outdoor",
    displayName: "Morning Run",
    warmup: {
      goal: { type: "time", value: 5, unit: "minutes" },
    },
    blocks: [
      {
        iterations: 4,
        steps: [
          {
            purpose: "work",
            goal: { type: "distance", value: 400, unit: "meters" },
            alert: { type: "pace", min: 4, max: 5, unit: "min/km" },
          },
          {
            purpose: "recovery",
            goal: { type: "time", value: 90, unit: "seconds" },
          },
        ],
      },
    ],
    cooldown: {
      goal: { type: "time", value: 5, unit: "minutes" },
    },
  });

  const buildSampleSingleGoalWorkout = (): SingleGoalWorkoutConfig => ({
    activityType: "running",
    locationType: "outdoor",
    displayName: "5K Run",
    goal: { type: "distance", value: 5, unit: "kilometers" },
  });

  const buildSamplePacerWorkout = (): PacerWorkoutConfig => ({
    activityType: "running",
    locationType: "outdoor",
    displayName: "Tempo Run",
    target: {
      type: "pace",
      value: 5,
      unit: "min/km",
    },
  });

  const buildSampleSwimBikeRunWorkout = (): SwimBikeRunWorkoutConfig => ({
    displayName: "Sprint Triathlon",
    activities: [
      { type: "swimming", locationType: "indoor" },
      { type: "cycling", locationType: "outdoor" },
      { type: "running", locationType: "outdoor" },
    ],
  });

  const customWorkoutConfig = useMemo(() => buildSampleCustomWorkout(), []);
  const singleGoalConfig = useMemo(() => buildSampleSingleGoalWorkout(), []);
  const pacerConfig = useMemo(() => buildSamplePacerWorkout(), []);
  const swimBikeRunConfig = useMemo(() => buildSampleSwimBikeRunWorkout(), []);

  const auth = useWorkoutAuthorization();
  const scheduled = useScheduledWorkouts();

  const { plan: customPlan } = useCustomWorkout(customWorkoutConfig);
  const { plan: singleGoalPlan } = useSingleGoalWorkout(singleGoalConfig);
  const { plan: pacerPlan } = usePacerWorkout(pacerConfig);
  const { plan: swimBikeRunPlan } = useSwimBikeRunWorkout(swimBikeRunConfig);

  const preview = async (planName: string, plan: any) => {
    try {
      if (!ensureIOS()) return;
      if (!plan) return;
      await plan.preview();
    } catch (error) {
      Alert.alert("Error", `${planName}: ${String(error)}`);
    }
  };

  const syncTomorrow = async (planName: string, plan: any) => {
    try {
      if (!ensureIOS()) return;
      if (!plan) return;

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(7, 0, 0, 0);

      const result = await plan.scheduleAndSync({
        year: tomorrow.getFullYear(),
        month: tomorrow.getMonth() + 1,
        day: tomorrow.getDate(),
        hour: 7,
        minute: 0,
      });

      Alert.alert("Workout Synced", `${planName}\nID: ${result.id}`);
    } catch (error) {
      Alert.alert("Error", `${planName}: ${String(error)}`);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.container}>
        <Text style={styles.header}>WorkoutKit Example (Hooks)</Text>

        <Group name="Module Info">
          <Text style={styles.smallText}>
            Note: this screen uses hooks only (no direct module calls).
          </Text>
        </Group>

        <Group name="Authorization">
          <Text style={styles.statusText}>Status: {auth.status ?? "Unknown"}</Text>
          {auth.error ? (
            <Text style={styles.smallText}>Error: {String(auth.error)}</Text>
          ) : null}
          <View style={styles.buttonRow}>
            <Button title="Refresh" onPress={() => auth.refresh()} />
            <Button
              title="Request Auth"
              onPress={async () => {
                const status = await auth.request();
                Alert.alert("Authorization", `Status: ${status}`);
              }}
            />
          </View>
        </Group>

        <Group name="Plans (Preview)">
          <Text style={styles.descriptionText}>
            These buttons call plan.preview() (system modal).
          </Text>
          <Button
            title="Preview Custom Plan"
            onPress={() => preview("Custom", customPlan)}
            disabled={!customPlan}
          />
          <Button
            title="Preview Single Goal Plan"
            onPress={() => preview("Single Goal", singleGoalPlan)}
            disabled={!singleGoalPlan}
          />
          <Button
            title="Preview Pacer Plan"
            onPress={() => preview("Pacer", pacerPlan)}
            disabled={!pacerPlan}
          />
          <Button
            title="Preview Swim/Bike/Run Plan"
            onPress={() => preview("SwimBikeRun", swimBikeRunPlan)}
            disabled={!swimBikeRunPlan}
          />
        </Group>

        <Group name="Plans (Sync Tomorrow 7AM)">
          <Text style={styles.descriptionText}>
            This calls plan.sync(date) which schedules the plan (syncs to Watch).
          </Text>
          <Button
            title="Sync Custom"
            onPress={() => syncTomorrow("Custom", customPlan)}
            disabled={!customPlan}
          />
          <Button
            title="Sync Single Goal"
            onPress={() => syncTomorrow("Single Goal", singleGoalPlan)}
            disabled={!singleGoalPlan}
          />
          <Button
            title="Sync Pacer"
            onPress={() => syncTomorrow("Pacer", pacerPlan)}
            disabled={!pacerPlan}
          />
          <Button
            title="Sync Swim/Bike/Run"
            onPress={() => syncTomorrow("SwimBikeRun", swimBikeRunPlan)}
            disabled={!swimBikeRunPlan}
          />
        </Group>

        <Group name="Scheduled Workouts">
          <Button title="Reload" onPress={() => scheduled.reload()} />
          <Button
            title="Remove All"
            onPress={() => scheduled.removeAll()}
            color="#ff4444"
          />
          {scheduled.error ? (
            <Text style={styles.smallText}>Error: {String(scheduled.error)}</Text>
          ) : null}
          {scheduled.workouts.length > 0 && (
            <View style={styles.workoutList}>
              <Text style={styles.listHeader}>
                Scheduled ({scheduled.workouts.length}):
              </Text>
              {scheduled.workouts.map((workout) => (
                <Text key={workout.id} style={styles.workoutItem}>
                  {workout.date.month}/{workout.date.day}/{workout.date.year}{' '}
                  {workout.date.hour}:{String(workout.date.minute).padStart(2, '0')}
                </Text>
              ))}
            </View>
          )}
        </Group>
      </ScrollView>
    </SafeAreaView>
  );
}

function Group(props: { name: string; children: React.ReactNode }) {
  return (
    <View style={styles.group}>
      <Text style={styles.groupHeader}>{props.name}</Text>
      {props.children}
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    fontSize: 28,
    fontWeight: 'bold',
    margin: 20,
    textAlign: 'center',
  },
  groupHeader: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 12,
  },
  group: {
    margin: 16,
    marginTop: 0,
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginTop: 8,
  },
  statusText: {
    fontSize: 16,
    marginBottom: 8,
  },
  smallText: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  descriptionText: {
    fontSize: 14,
    color: '#666',
    marginBottom: 12,
  },
  spacer: {
    height: 8,
  },
  workoutList: {
    marginTop: 16,
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopColor: '#eee',
  },
  listHeader: {
    fontSize: 14,
    fontWeight: '600',
    marginBottom: 8,
  },
  workoutItem: {
    fontSize: 14,
    color: '#333',
    paddingVertical: 4,
  },
});
