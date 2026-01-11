import * as React from 'react';

import { ReactNativeWorkoutsViewProps } from './ReactNativeWorkouts.types';

export default function ReactNativeWorkoutsView(props: ReactNativeWorkoutsViewProps) {
  return (
    <div>
      <iframe
        style={{ flex: 1 }}
        src={props.url}
        onLoad={() => props.onLoad({ nativeEvent: { url: props.url } })}
      />
    </div>
  );
}
