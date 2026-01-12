import ExpoModulesCore
import WorkoutKit
import HealthKit
import SwiftUI
import UIKit

// MARK: - Shared Objects

public final class WorkoutPlanObject: SharedObject {
    // Keep the plan opaque so this object can be referenced in ModuleDefinition on iOS < 17.
    // We only cast/use WorkoutKit types behind runtime availability checks.
    fileprivate let planHandle: Any
    fileprivate let planId: String
    fileprivate let kind: String
    fileprivate let sourceConfig: [String: Any]

    fileprivate init(planHandle: Any, planId: String, kind: String, sourceConfig: [String: Any]) {
        self.planHandle = planHandle
        self.planId = planId
        self.kind = kind
        self.sourceConfig = sourceConfig
        super.init()
    }

    fileprivate func export() -> [String: Any] {
        return [
            "id": planId,
            "kind": kind,
            "config": sourceConfig
        ]
    }

    @MainActor
    fileprivate func preview() async throws {
        guard #available(iOS 17.0, *) else {
            throw Exception(name: "Unavailable", description: "WorkoutKit requires iOS 17+. This API is unavailable on the current OS version.")
        }
        let plan = try self.getWorkoutPlan()
        try await presentWorkoutPreview(plan)
    }

    fileprivate func schedule(at date: DateComponents) async throws -> [String: Any] {
        guard #available(iOS 17.0, *) else {
            throw Exception(name: "Unavailable", description: "WorkoutKit requires iOS 17+. This API is unavailable on the current OS version.")
        }

        let plan = try self.getWorkoutPlan()
        await WorkoutScheduler.shared.schedule(plan, at: date)
        return [
            "success": true,
            "id": planId
        ]
    }

    @available(iOS 17.0, *)
    private func getWorkoutPlan() throws -> WorkoutPlan {
        guard let plan = planHandle as? WorkoutPlan else {
            throw Exception(name: "InvalidState", description: "Workout plan handle is invalid")
        }
        return plan
    }
}

public class ReactNativeWorkoutsModule: Module {
    private let healthStore = HKHealthStore()

    public func definition() -> ModuleDefinition {
        Name("ReactNativeWorkouts")

        // MARK: - Constants

        Constants([
            "isAvailable": HKHealthStore.isHealthDataAvailable()
        ])

        // MARK: - Events

        Events("onAuthorizationChange")

        let workoutKitUnavailableMessage = "WorkoutKit requires iOS 17+. This API is unavailable on the current OS version."

        // MARK: - Shared Object API (WorkoutPlan)
        Class("WorkoutPlan", WorkoutPlanObject.self) {
            Property("id") { planObject in
                return planObject.planId
            }

            Property("kind") { planObject in
                return planObject.kind
            }

            Function("export") { planObject in
                return planObject.export()
            }

            AsyncFunction("preview") { (planObject: WorkoutPlanObject) async throws -> Bool in
                try await planObject.preview()
                return true
            }

            // Schedules the plan using Apple's WorkoutScheduler (this is how it syncs to the Watch Workout app).
            AsyncFunction("scheduleAndSync") { (planObject: WorkoutPlanObject, date: [String: Any]) async throws -> [String: Any] in
                let dateComponents = self.parseDateComponents(from: date)
                return try await planObject.schedule(at: dateComponents)
            }
        }

        // MARK: - Authorization

        AsyncFunction("getAuthorizationStatus") { () async throws -> String in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            let status = await WorkoutScheduler.shared.authorizationState
            return self.authorizationStateToString(status)
        }

        AsyncFunction("requestAuthorization") { () async throws -> String in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            let status = await WorkoutScheduler.shared.requestAuthorization()
            return self.authorizationStateToString(status)
        }

        // MARK: - Workout Validation

        AsyncFunction("supportsGoal") { (activityType: String, locationType: String, goalType: String) throws -> Bool in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let activity = self.parseActivityType(activityType),
                  let location = self.parseLocationType(locationType),
                  let goal = self.parseGoalTypeForValidation(goalType) else {
                return false
            }

            return CustomWorkout.supportsGoal(goal, activity: activity, location: location)
        }

        // MARK: - Plan factories (return a WorkoutPlanObject handle to JS)

        AsyncFunction("createCustomWorkoutPlan") { (config: [String: Any]) throws -> WorkoutPlanObject in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            let workout = try self.buildCustomWorkout(from: config)
            try self.validateCustomWorkout(workout)
            let plan = WorkoutPlan(.custom(workout))
            return WorkoutPlanObject(planHandle: plan, planId: plan.id.uuidString, kind: "custom", sourceConfig: config)
        }

        AsyncFunction("createSingleGoalWorkoutPlan") { (config: [String: Any]) throws -> WorkoutPlanObject in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let activityTypeStr = config["activityType"] as? String,
                  let activity = self.parseActivityType(activityTypeStr),
                  let goalConfig = config["goal"] as? [String: Any] else {
                throw Exception(name: "InvalidConfig", description: "Missing required fields: activityType, goal")
            }

            let goal = try self.parseWorkoutGoal(from: goalConfig)
            let location = self.parseLocationType(config["locationType"] as? String ?? "outdoor") ?? .outdoor

            guard SingleGoalWorkout.supportsGoal(goal, activity: activity, location: location) else {
                throw Exception(name: "ValidationError", description: "Single goal workout not supported for this activity/location/goal")
            }

            let workout = SingleGoalWorkout(activity: activity, location: location, goal: goal)
            let plan = WorkoutPlan(.goal(workout))
            return WorkoutPlanObject(planHandle: plan, planId: plan.id.uuidString, kind: "singleGoal", sourceConfig: config)
        }

        AsyncFunction("createPacerWorkoutPlan") { (config: [String: Any]) throws -> WorkoutPlanObject in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let activityTypeStr = config["activityType"] as? String,
                  let activity = self.parseActivityType(activityTypeStr),
                  let targetConfig = config["target"] as? [String: Any] else {
                throw Exception(name: "InvalidConfig", description: "Missing required fields: activityType, target")
            }

            let location = self.parseLocationType(config["locationType"] as? String ?? "outdoor") ?? .outdoor
            let (distance, time) = try self.parsePacerDistanceAndTime(from: targetConfig)

            let workout = PacerWorkout(activity: activity, location: location, distance: distance, time: time)
            let plan = WorkoutPlan(.pacer(workout))
            return WorkoutPlanObject(planHandle: plan, planId: plan.id.uuidString, kind: "pacer", sourceConfig: config)
        }

        AsyncFunction("createSwimBikeRunWorkoutPlan") { (config: [String: Any]) throws -> WorkoutPlanObject in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let activitiesConfig = config["activities"] as? [[String: Any]] else {
                throw Exception(name: "InvalidConfig", description: "Missing required field: activities")
            }

            let displayName = config["displayName"] as? String
            let activities = try self.parseSwimBikeRunActivities(from: activitiesConfig)

            guard SwimBikeRunWorkout.supportsActivityOrdering(activities) else {
                throw Exception(name: "ValidationError", description: "Unsupported activity ordering for SwimBikeRun workout")
            }

            let workout = SwimBikeRunWorkout(activities: activities, displayName: displayName)
            let plan = WorkoutPlan(.swimBikeRun(workout))
            return WorkoutPlanObject(planHandle: plan, planId: plan.id.uuidString, kind: "swimBikeRun", sourceConfig: config)
        }

        // MARK: - Custom Workout Creation

        AsyncFunction("createCustomWorkout") { (config: [String: Any]) throws -> [String: Any] in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            let workout = try self.buildCustomWorkout(from: config)
            try self.validateCustomWorkout(workout)

            return [
                "valid": true,
                "displayName": workout.displayName ?? (config["displayName"] as? String ?? "")
            ]
        }

        // MARK: - Workout Preview (system modal)

        AsyncFunction("previewWorkout") { (config: [String: Any]) async throws -> Bool in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            let workout = try self.buildCustomWorkout(from: config)
            try self.validateCustomWorkout(workout)
            let plan = WorkoutPlan(.custom(workout))

            try await presentWorkoutPreview(plan)
            return true
        }

        AsyncFunction("previewSingleGoalWorkout") { (config: [String: Any]) async throws -> Bool in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let activityTypeStr = config["activityType"] as? String,
                  let activity = self.parseActivityType(activityTypeStr),
                  let goalConfig = config["goal"] as? [String: Any] else {
                throw Exception(name: "InvalidConfig", description: "Missing required fields: activityType, goal")
            }

            let goal = try self.parseWorkoutGoal(from: goalConfig)
            let location = self.parseLocationType(config["locationType"] as? String ?? "outdoor") ?? .outdoor

            guard SingleGoalWorkout.supportsGoal(goal, activity: activity, location: location) else {
                throw Exception(name: "ValidationError", description: "Single goal workout not supported for this activity/location/goal")
            }

            let workout = SingleGoalWorkout(activity: activity, location: location, goal: goal)
            let plan = WorkoutPlan(.goal(workout))

            try await presentWorkoutPreview(plan)
            return true
        }

        AsyncFunction("previewPacerWorkout") { (config: [String: Any]) async throws -> Bool in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let activityTypeStr = config["activityType"] as? String,
                  let activity = self.parseActivityType(activityTypeStr),
                  let targetConfig = config["target"] as? [String: Any] else {
                throw Exception(name: "InvalidConfig", description: "Missing required fields: activityType, target")
            }

            let location = self.parseLocationType(config["locationType"] as? String ?? "outdoor") ?? .outdoor
            let (distance, time) = try self.parsePacerDistanceAndTime(from: targetConfig)

            let workout = PacerWorkout(activity: activity, location: location, distance: distance, time: time)
            let plan = WorkoutPlan(.pacer(workout))

            try await presentWorkoutPreview(plan)
            return true
        }

        // MARK: - Scheduled Workouts

        AsyncFunction("scheduleWorkout") { (config: [String: Any], date: [String: Any]) async throws -> [String: Any] in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            let workout = try self.buildCustomWorkout(from: config)
            try self.validateCustomWorkout(workout)

            let plan = WorkoutPlan(.custom(workout))
            let dateComponents = self.parseDateComponents(from: date)

            await WorkoutScheduler.shared.schedule(plan, at: dateComponents)
            return [
                "success": true,
                "id": plan.id.uuidString
            ]
        }

        AsyncFunction("getScheduledWorkouts") { () async throws -> [[String: Any]] in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            let workouts = await WorkoutScheduler.shared.scheduledWorkouts
            return workouts.map { scheduled in
                return [
                    "id": scheduled.plan.id.uuidString,
                    "date": self.dateComponentsToDict(scheduled.date)
                ]
            }
        }

        AsyncFunction("removeScheduledWorkout") { (id: String) async throws -> Bool in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let uuid = UUID(uuidString: id) else {
                throw Exception(name: "InvalidID", description: "Invalid workout ID format")
            }

            let workouts = await WorkoutScheduler.shared.scheduledWorkouts
            guard let workout = workouts.first(where: { $0.plan.id == uuid }) else {
                throw Exception(name: "NotFound", description: "Workout not found")
            }

            await WorkoutScheduler.shared.remove(workout.plan, at: workout.date)
            return true
        }

        AsyncFunction("removeAllScheduledWorkouts") { () async throws -> Bool in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            await WorkoutScheduler.shared.removeAllWorkouts()
            return true
        }

        // MARK: - Single Goal Workout

        AsyncFunction("createSingleGoalWorkout") { (config: [String: Any]) throws -> [String: Any] in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let activityTypeStr = config["activityType"] as? String,
                  let activity = self.parseActivityType(activityTypeStr),
                  let goalConfig = config["goal"] as? [String: Any] else {
                throw Exception(name: "InvalidConfig", description: "Missing required fields: activityType, goal")
            }

            let goal = try self.parseWorkoutGoal(from: goalConfig)
            let location = self.parseLocationType(config["locationType"] as? String ?? "outdoor") ?? .outdoor
            let displayName = config["displayName"] as? String ?? ""

            guard SingleGoalWorkout.supportsGoal(goal, activity: activity, location: location) else {
                throw Exception(name: "ValidationError", description: "Single goal workout not supported for this activity/location/goal")
            }

            return [
                "valid": true,
                "displayName": displayName
            ]
        }

        AsyncFunction("scheduleSingleGoalWorkout") { (config: [String: Any], date: [String: Any]) async throws -> [String: Any] in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let activityTypeStr = config["activityType"] as? String,
                  let activity = self.parseActivityType(activityTypeStr),
                  let goalConfig = config["goal"] as? [String: Any] else {
                throw Exception(name: "InvalidConfig", description: "Missing required fields: activityType, goal")
            }

            let goal = try self.parseWorkoutGoal(from: goalConfig)
            let location = self.parseLocationType(config["locationType"] as? String ?? "outdoor") ?? .outdoor

            guard SingleGoalWorkout.supportsGoal(goal, activity: activity, location: location) else {
                throw Exception(name: "ValidationError", description: "Single goal workout not supported for this activity/location/goal")
            }

            let workout = SingleGoalWorkout(activity: activity, location: location, goal: goal)
            let plan = WorkoutPlan(.goal(workout))

            let dateComponents = self.parseDateComponents(from: date)
            await WorkoutScheduler.shared.schedule(plan, at: dateComponents)
            return [
                "success": true,
                "id": plan.id.uuidString
            ]
        }

        // MARK: - Pacer Workout

        AsyncFunction("createPacerWorkout") { (config: [String: Any]) throws -> [String: Any] in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let activityTypeStr = config["activityType"] as? String,
                  let activity = self.parseActivityType(activityTypeStr),
                  let targetConfig = config["target"] as? [String: Any] else {
                throw Exception(name: "InvalidConfig", description: "Missing required fields: activityType, target")
            }

            let location = self.parseLocationType(config["locationType"] as? String ?? "outdoor") ?? .outdoor
            let displayName = config["displayName"] as? String ?? ""

            let (distance, time) = try self.parsePacerDistanceAndTime(from: targetConfig)
            _ = PacerWorkout(activity: activity, location: location, distance: distance, time: time)

            return [
                "valid": true,
                "displayName": displayName
            ]
        }

        AsyncFunction("schedulePacerWorkout") { (config: [String: Any], date: [String: Any]) async throws -> [String: Any] in
            guard #available(iOS 17.0, *) else {
                throw Exception(name: "Unavailable", description: workoutKitUnavailableMessage)
            }

            guard let activityTypeStr = config["activityType"] as? String,
                  let activity = self.parseActivityType(activityTypeStr),
                  let targetConfig = config["target"] as? [String: Any] else {
                throw Exception(name: "InvalidConfig", description: "Missing required fields: activityType, target")
            }

            let location = self.parseLocationType(config["locationType"] as? String ?? "outdoor") ?? .outdoor

            let (distance, time) = try self.parsePacerDistanceAndTime(from: targetConfig)
            let workout = PacerWorkout(activity: activity, location: location, distance: distance, time: time)
            let plan = WorkoutPlan(.pacer(workout))

            let dateComponents = self.parseDateComponents(from: date)
            await WorkoutScheduler.shared.schedule(plan, at: dateComponents)
            return [
                "success": true,
                "id": plan.id.uuidString
            ]
        }

        // MARK: - Activity Types

        Function("getSupportedActivityTypes") { () -> [String] in
            return [
                "running",
                "cycling",
                "walking",
                "hiking",
                "swimming",
                "rowing",
                "elliptical",
                "stairClimbing",
                "highIntensityIntervalTraining",
                "yoga",
                "functionalStrengthTraining",
                "traditionalStrengthTraining",
                "dance",
                "jumpRope",
                "coreTraining",
                "pilates",
                "kickboxing",
                "stairs",
                "stepTraining",
                "wheelchairRunPace",
                "wheelchairWalkPace"
            ]
        }

        Function("getSupportedGoalTypes") { () -> [String] in
            return [
                "open",
                "distance",
                "time",
                "energy"
            ]
        }

        Function("getSupportedLocationTypes") { () -> [String] in
            return [
                "indoor",
                "outdoor"
            ]
        }
    }

    // MARK: - Helper Methods

    @available(iOS 17.0, *)
    private func authorizationStateToString(_ state: WorkoutScheduler.AuthorizationState) -> String {
        switch state {
        case .authorized:
            return "authorized"
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        default:
            return "unknown"
        }
    }

    @available(iOS 17.0, *)
    private func parseSwimBikeRunActivities(from activitiesConfig: [[String: Any]]) throws -> [SwimBikeRunWorkout.Activity] {
        var activities: [SwimBikeRunWorkout.Activity] = []

        for activityConfig in activitiesConfig {
            guard let type = activityConfig["type"] as? String else {
                throw Exception(name: "InvalidConfig", description: "Each activity must have a type")
            }

            switch type.lowercased() {
            case "running":
                let location = self.parseLocationType(activityConfig["locationType"] as? String ?? "outdoor") ?? .outdoor
                activities.append(.running(location))
            case "cycling":
                let location = self.parseLocationType(activityConfig["locationType"] as? String ?? "outdoor") ?? .outdoor
                activities.append(.cycling(location))
            case "swimming":
                let swimLocation = self.parseSwimmingLocationType(activityConfig["locationType"] as? String ?? "pool")
                activities.append(.swimming(swimLocation))
            default:
                throw Exception(name: "InvalidConfig", description: "Unsupported SwimBikeRun activity type: \(type)")
            }
        }

        return activities
    }

    private func parseSwimmingLocationType(_ type: String?) -> HKWorkoutSwimmingLocationType {
        guard let type = type else { return .unknown }
        switch type.lowercased() {
        case "pool", "indoor":
            return .pool
        case "openwater", "open_water", "outdoor":
            return .openWater
        default:
            return .unknown
        }
    }

    private func parseActivityType(_ type: String) -> HKWorkoutActivityType? {
        switch type.lowercased() {
        case "running": return .running
        case "cycling": return .cycling
        case "walking": return .walking
        case "hiking": return .hiking
        case "swimming": return .swimming
        case "rowing": return .rowing
        case "elliptical": return .elliptical
        case "stairclimbing": return .stairClimbing
        case "highintensityintervaltraining", "hiit": return .highIntensityIntervalTraining
        case "yoga": return .yoga
        case "functionalstrengthtraining": return .functionalStrengthTraining
        case "traditionalstrengthtraining": return .traditionalStrengthTraining
        case "dance": return .cardioDance
        case "jumprope": return .jumpRope
        case "coretraining": return .coreTraining
        case "pilates": return .pilates
        case "kickboxing": return .kickboxing
        case "stairs": return .stairs
        case "steptraining": return .stepTraining
        case "wheelchairrunpace": return .wheelchairRunPace
        case "wheelchairwalkpace": return .wheelchairWalkPace
        default: return nil
        }
    }

    private func parseLocationType(_ type: String?) -> HKWorkoutSessionLocationType? {
        guard let type = type else { return .outdoor }
        switch type.lowercased() {
        case "indoor": return .indoor
        case "outdoor": return .outdoor
        default: return .unknown
        }
    }

    @available(iOS 17.0, *)
    private func parseGoalTypeForValidation(_ type: String) -> WorkoutGoal? {
        switch type.lowercased() {
        case "open": return .open
        case "distance": return .distance(1, .meters)
        case "time": return .time(1, .seconds)
        case "energy": return .energy(1, .kilocalories)
        default: return nil
        }
    }

    @available(iOS 17.0, *)
    private func parseWorkoutGoal(from config: [String: Any]) throws -> WorkoutGoal {
        guard let type = config["type"] as? String else {
            throw Exception(name: "InvalidGoal", description: "Goal type is required")
        }

        switch type.lowercased() {
        case "open":
            return .open

        case "distance":
            guard let value = config["value"] as? Double else {
                throw Exception(name: "InvalidGoal", description: "Distance value is required")
            }
            let unitStr = config["unit"] as? String ?? "meters"
            let unit = self.parseDistanceUnit(unitStr)
            return .distance(value, unit)

        case "time":
            guard let value = config["value"] as? Double else {
                throw Exception(name: "InvalidGoal", description: "Time value is required")
            }
            let unitStr = config["unit"] as? String ?? "seconds"
            let unit = self.parseTimeUnit(unitStr)
            return .time(value, unit)

        case "energy":
            guard let value = config["value"] as? Double else {
                throw Exception(name: "InvalidGoal", description: "Energy value is required")
            }
            let unitStr = config["unit"] as? String ?? "kilocalories"
            let unit = self.parseEnergyUnit(unitStr)
            return .energy(value, unit)

        default:
            throw Exception(name: "InvalidGoal", description: "Unknown goal type: \(type)")
        }
    }

    private func parseDistanceUnit(_ unit: String) -> UnitLength {
        switch unit.lowercased() {
        case "meters", "m": return .meters
        case "kilometers", "km": return .kilometers
        case "miles", "mi": return .miles
        case "yards", "yd": return .yards
        case "feet", "ft": return .feet
        default: return .meters
        }
    }

    private func parseTimeUnit(_ unit: String) -> UnitDuration {
        switch unit.lowercased() {
        case "seconds", "s", "sec": return .seconds
        case "minutes", "min": return .minutes
        case "hours", "h", "hr": return .hours
        default: return .seconds
        }
    }

    private func parseEnergyUnit(_ unit: String) -> UnitEnergy {
        switch unit.lowercased() {
        case "kilocalories", "kcal", "cal": return .kilocalories
        case "kilojoules", "kj": return .kilojoules
        default: return .kilocalories
        }
    }

    private func parsePacerDistanceAndTime(from config: [String: Any]) throws -> (distance: Measurement<UnitLength>, time: Measurement<UnitDuration>) {
        guard let type = config["type"] as? String else {
            throw Exception(name: "InvalidTarget", description: "Target type is required")
        }

        guard let value = config["value"] as? Double else {
            throw Exception(name: "InvalidTarget", description: "Target value is required")
        }

        switch type.lowercased() {
        case "pace":
            // value is minutes per unitLength (km or mile)
            let unitStr = config["unit"] as? String ?? "minutesPerKilometer"
            let lengthUnit = self.parsePaceUnit(unitStr)
            let distance = Measurement(value: 1, unit: lengthUnit)
            let time = Measurement(value: value, unit: UnitDuration.minutes)
            return (distance, time)

        case "speed":
            // value is speed in the given unit; we convert it to a distance/time pair
            let unitStr = config["unit"] as? String ?? "metersPerSecond"
            let speedUnit = self.parseSpeedUnit(unitStr)
            let speed = Measurement(value: value, unit: speedUnit)

            let preferredDistance: Measurement<UnitLength>
            switch unitStr.lowercased() {
            case "milesperhour", "mph":
                preferredDistance = Measurement(value: 1, unit: UnitLength.miles)
            case "kilometersperhour", "kph", "km/h":
                preferredDistance = Measurement(value: 1, unit: UnitLength.kilometers)
            default:
                preferredDistance = Measurement(value: 1000, unit: UnitLength.meters)
            }

            let speedMps = speed.converted(to: UnitSpeed.metersPerSecond).value
            let distanceMeters = preferredDistance.converted(to: UnitLength.meters).value
            guard speedMps > 0 else {
                throw Exception(name: "InvalidTarget", description: "Speed must be > 0")
            }
            let seconds = distanceMeters / speedMps
            return (preferredDistance, Measurement(value: seconds, unit: UnitDuration.seconds))

        default:
            throw Exception(name: "InvalidTarget", description: "Unknown target type: \(type)")
        }
    }

    private func parseSpeedUnit(_ unit: String) -> UnitSpeed {
        switch unit.lowercased() {
        case "meterspersecond", "mps", "m/s": return .metersPerSecond
        case "kilometersperhour", "kph", "km/h": return .kilometersPerHour
        case "milesperhour", "mph": return .milesPerHour
        default: return .metersPerSecond
        }
    }

    private func parsePaceUnit(_ unit: String) -> UnitLength {
        switch unit.lowercased() {
        case "minutesperkilometer", "min/km": return .kilometers
        case "minutespermile", "min/mi": return .miles
        default: return .kilometers
        }
    }

    @available(iOS 17.0, *)
    private func parseStepPurpose(_ purpose: String) -> IntervalStep.Purpose {
        switch purpose.lowercased() {
        case "work": return .work
        case "recovery": return .recovery
        default: return .work
        }
    }

    @available(iOS 17.0, *)
    private func parseWorkoutAlert(from config: [String: Any]) throws -> (any WorkoutAlert)? {
        guard let type = config["type"] as? String else {
            return nil
        }

        switch type.lowercased() {
        case "heartrate", "heart_rate":
            if let zone = config["zone"] as? Int {
                return HeartRateZoneAlert.heartRate(zone: zone)
            } else if let min = config["min"] as? Double, let max = config["max"] as? Double {
                return HeartRateRangeAlert.heartRate(Double(min)...Double(max))
            }

        case "pace":
            guard let min = config["min"] as? Double, let max = config["max"] as? Double else {
                return nil
            }
            let unitStr = config["unit"] as? String ?? "minutesPerKilometer"
            let lengthUnit = self.parsePaceUnit(unitStr)
            return try self.paceRangeAlert(minMinutesPerUnit: min, maxMinutesPerUnit: max, unit: lengthUnit)

        case "speed":
            guard let min = config["min"] as? Double, let max = config["max"] as? Double else {
                return nil
            }
            let unitStr = config["unit"] as? String ?? "metersPerSecond"
            let unit = self.parseSpeedUnit(unitStr)
            return SpeedRangeAlert.speed(min...max, unit: unit)

        case "cadence":
            guard let min = config["min"] as? Double, let max = config["max"] as? Double else {
                return nil
            }
            return CadenceRangeAlert.cadence(min...max)

        case "power":
            guard let min = config["min"] as? Double, let max = config["max"] as? Double else {
                return nil
            }
            if #available(iOS 17.4, *) {
                return PowerRangeAlert.power(min...max, unit: .watts, metric: .current)
            }
            return nil

        default:
            return nil
        }

        return nil
    }

    @available(iOS 17.0, *)
    private func paceRangeAlert(minMinutesPerUnit: Double, maxMinutesPerUnit: Double, unit: UnitLength) throws -> (any WorkoutAlert)? {
        guard minMinutesPerUnit > 0, maxMinutesPerUnit > 0 else {
            throw Exception(name: "InvalidAlert", description: "Pace min/max must be > 0")
        }

        let distanceMeters = Measurement(value: 1, unit: unit).converted(to: .meters).value
        let minSeconds = minMinutesPerUnit * 60.0
        let maxSeconds = maxMinutesPerUnit * 60.0

        // Pace is inverse of speed. For a range [minPace..maxPace] (minutes/unit),
        // the equivalent speed range is [distance/maxPace .. distance/minPace].
        let lowSpeed = distanceMeters / maxSeconds
        let highSpeed = distanceMeters / minSeconds
        return SpeedRangeAlert.speed(lowSpeed...highSpeed, unit: .metersPerSecond)
    }

    @available(iOS 17.0, *)
    private func validateCustomWorkout(_ workout: CustomWorkout) throws {
        let activity = workout.activity
        let location = workout.location

        func validateStep(_ step: WorkoutStep) throws {
            if !CustomWorkout.supportsGoal(step.goal, activity: activity, location: location) {
                throw Exception(name: "ValidationError", description: "Unsupported workout goal for activity/location")
            }
            if let alert = step.alert {
                // Prefer explicit validation for CustomWorkout context.
                if !CustomWorkout.supportsAlert(alert, activity: activity, location: location) {
                    throw Exception(name: "ValidationError", description: "Unsupported workout alert for activity/location")
                }
            }
        }

        if let warmup = workout.warmup {
            try validateStep(warmup)
        }
        if let cooldown = workout.cooldown {
            try validateStep(cooldown)
        }
        for block in workout.blocks {
            for intervalStep in block.steps {
                try validateStep(intervalStep.step)
            }
        }
    }

    @available(iOS 17.0, *)
    private func buildCustomWorkout(from config: [String: Any]) throws -> CustomWorkout {
        guard let activityTypeStr = config["activityType"] as? String,
              let activity = self.parseActivityType(activityTypeStr) else {
            throw Exception(name: "InvalidConfig", description: "Invalid or missing activityType")
        }

        let location = self.parseLocationType(config["locationType"] as? String) ?? .outdoor
        let displayName = config["displayName"] as? String

        var warmup: WorkoutStep?
        if let warmupConfig = config["warmup"] as? [String: Any] {
            warmup = try self.parseWorkoutStep(from: warmupConfig)
        }

        var cooldown: WorkoutStep?
        if let cooldownConfig = config["cooldown"] as? [String: Any] {
            cooldown = try self.parseWorkoutStep(from: cooldownConfig)
        }

        var blocks: [IntervalBlock] = []
        if let blocksConfig = config["blocks"] as? [[String: Any]] {
            for blockConfig in blocksConfig {
                let block = try self.parseIntervalBlock(from: blockConfig)
                blocks.append(block)
            }
        }

        return CustomWorkout(
            activity: activity,
            location: location,
            displayName: displayName,
            warmup: warmup,
            blocks: blocks,
            cooldown: cooldown
        )
    }

    @available(iOS 17.0, *)
    private func parseWorkoutStep(from config: [String: Any]) throws -> WorkoutStep {
        let goalConfig = config["goal"] as? [String: Any]
        let goal: WorkoutGoal

        if let goalConfig = goalConfig {
            goal = try self.parseWorkoutGoal(from: goalConfig)
        } else {
            goal = .open
        }

        var step = WorkoutStep(goal: goal)

        if let alertConfig = config["alert"] as? [String: Any] {
            step.alert = try self.parseWorkoutAlert(from: alertConfig)
        }

        return step
    }

    @available(iOS 17.0, *)
    private func parseIntervalStep(from config: [String: Any]) throws -> IntervalStep {
        let purposeStr = config["purpose"] as? String ?? "work"
        let purpose = self.parseStepPurpose(purposeStr)

        var step = IntervalStep(purpose)

        if let goalConfig = config["goal"] as? [String: Any] {
            step.step.goal = try self.parseWorkoutGoal(from: goalConfig)
        }

        if let alertConfig = config["alert"] as? [String: Any] {
            step.step.alert = try self.parseWorkoutAlert(from: alertConfig)
        }

        return step
    }

    @available(iOS 17.0, *)
    private func parseIntervalBlock(from config: [String: Any]) throws -> IntervalBlock {
        var block = IntervalBlock()

        if let iterations = config["iterations"] as? Int {
            block.iterations = iterations
        }

        if let stepsConfig = config["steps"] as? [[String: Any]] {
            var steps: [IntervalStep] = []
            for stepConfig in stepsConfig {
                let step = try self.parseIntervalStep(from: stepConfig)
                steps.append(step)
            }
            block.steps = steps
        }

        return block
    }

    private func parseDateComponents(from dict: [String: Any]) -> DateComponents {
        var components = DateComponents()

        if let year = dict["year"] as? Int {
            components.year = year
        }
        if let month = dict["month"] as? Int {
            components.month = month
        }
        if let day = dict["day"] as? Int {
            components.day = day
        }
        if let hour = dict["hour"] as? Int {
            components.hour = hour
        }
        if let minute = dict["minute"] as? Int {
            components.minute = minute
        }

        return components
    }

    private func dateComponentsToDict(_ components: DateComponents) -> [String: Any] {
        var dict: [String: Any] = [:]

        if let year = components.year {
            dict["year"] = year
        }
        if let month = components.month {
            dict["month"] = month
        }
        if let day = components.day {
            dict["day"] = day
        }
        if let hour = components.hour {
            dict["hour"] = hour
        }
        if let minute = components.minute {
            dict["minute"] = minute
        }

        return dict
    }
}

// MARK: - Workout Preview presentation helpers

@MainActor
@available(iOS 17.0, *)
fileprivate func presentWorkoutPreview(_ plan: WorkoutPlan) async throws {
    guard let viewController = topMostViewController() else {
        throw Exception(name: "NoViewController", description: "Unable to find a view controller to present from")
    }

    let host = UIHostingController(rootView: WorkoutPreviewLauncher(plan: plan))
    host.modalPresentationStyle = .overFullScreen
    host.view.backgroundColor = .clear

    viewController.present(host, animated: true)
}

fileprivate func topMostViewController() -> UIViewController? {
    // React Native / Expo apps can temporarily be in `.foregroundInactive` during transitions.
    // Also, `isKeyWindow` isn't always set early, so we fall back to a normal-level window.
    let windowScenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { scene in
            switch scene.activationState {
            case .foregroundActive, .foregroundInactive:
                return true
            default:
                return false
            }
        }

    let candidateWindows = windowScenes.flatMap { $0.windows }
    let keyWindow =
        candidateWindows.first(where: { $0.isKeyWindow }) ??
        candidateWindows.first(where: { $0.windowLevel == .normal }) ??
        candidateWindows.first ??
        UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ??
        UIApplication.shared.windows.first

    guard let root = keyWindow?.rootViewController else { return nil }
    return topMostViewController(from: root)
}

fileprivate func topMostViewController(from root: UIViewController) -> UIViewController {
    if let presented = root.presentedViewController {
        return topMostViewController(from: presented)
    }
    if let nav = root as? UINavigationController, let visible = nav.visibleViewController {
        return topMostViewController(from: visible)
    }
    if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
        return topMostViewController(from: selected)
    }
    return root
}

@available(iOS 17.0, *)
private struct WorkoutPreviewLauncher: View {
    let plan: WorkoutPlan

    @State private var isPresented = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .onAppear {
                isPresented = true
            }
            .workoutPreview(plan, isPresented: $isPresented)
            .onChange(of: isPresented) { presented in
                if !presented {
                    dismiss()
                }
            }
    }
}
