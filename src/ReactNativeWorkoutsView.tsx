import { requireNativeView } from 'expo';
import * as React from 'react';

import { ReactNativeWorkoutsViewProps } from './ReactNativeWorkouts.types';

const NativeView: React.ComponentType<ReactNativeWorkoutsViewProps> =
  requireNativeView('ReactNativeWorkouts');

export default function ReactNativeWorkoutsView(props: ReactNativeWorkoutsViewProps) {
  return <NativeView {...props} />;
}
