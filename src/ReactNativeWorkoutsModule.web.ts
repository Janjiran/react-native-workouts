import { registerWebModule, NativeModule } from 'expo';

import { ReactNativeWorkoutsModuleEvents } from './ReactNativeWorkouts.types';

class ReactNativeWorkoutsModule extends NativeModule<ReactNativeWorkoutsModuleEvents> {
  PI = Math.PI;
  async setValueAsync(value: string): Promise<void> {
    this.emit('onChange', { value });
  }
  hello() {
    return 'Hello world! 👋';
  }
}

export default registerWebModule(ReactNativeWorkoutsModule, 'ReactNativeWorkoutsModule');
