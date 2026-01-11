import { NativeModule, requireNativeModule } from 'expo';

import { ReactNativeWorkoutsModuleEvents } from './ReactNativeWorkouts.types';

declare class ReactNativeWorkoutsModule extends NativeModule<ReactNativeWorkoutsModuleEvents> {
  PI: number;
  hello(): string;
  setValueAsync(value: string): Promise<void>;
}

// This call loads the native module object from the JSI.
export default requireNativeModule<ReactNativeWorkoutsModule>('ReactNativeWorkouts');
