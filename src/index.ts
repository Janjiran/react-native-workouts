// Reexport the native module. On web, it will be resolved to ReactNativeWorkoutsModule.web.ts
// and on native platforms to ReactNativeWorkoutsModule.ts
export { default } from './ReactNativeWorkoutsModule';
export { default as ReactNativeWorkoutsView } from './ReactNativeWorkoutsView';
export * from  './ReactNativeWorkouts.types';
