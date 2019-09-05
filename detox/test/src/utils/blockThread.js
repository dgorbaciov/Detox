import {Settings} from 'react-native';

export function blockThread(s) {
  let res;

  const duration = measure(uselessOperation);
  const times = s / duration;

  for (let i = 0; i < times; i++) {
    res = uselessOperation();
  }

  return res;
}

export function simulateLongStartIfConfigured() {
  const seconds = +Settings.get('delayJsThreadBySeconds');
  if (seconds > 0) {
    blockThread(seconds);
  }/* else {
    blockThread(10);
  }*/
}

function measure(fn) {
  const t0 = Date.now();
  fn();
  const t1 = Date.now();

  return 1E-3 * Math.max(t1 - t0, 1);
}

function uselessOperation(times = 100000) {
  let acc = 0, i;
  for (i = 0; i < times; i++) {
    acc += -0.5 + Math.random();
  }
  return acc;
}
