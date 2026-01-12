require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'ReactNativeWorkouts'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = package['homepage']
  s.platforms      = {
    # The module APIs require iOS 17+ at runtime (WorkoutKit), but we keep the
    # deployment target lower so apps can still build with e.g. iOS 15 targets.
    # Calls on iOS < 17 will throw a descriptive "Unavailable" error.
    :ios => '15.1'
  }
  s.swift_version  = '5.9'
  s.source         = { git: 'https://github.com/Janjiran/react-native-workouts' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # HealthKit exists on older iOS versions, keep it strongly linked.
  s.frameworks = 'HealthKit'
  # WorkoutKit does NOT exist on iOS < 17; weak-link it so the app can still load.
  s.weak_frameworks = 'WorkoutKit'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
end
