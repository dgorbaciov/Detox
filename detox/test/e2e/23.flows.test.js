describe('Flows', () => {

  it('should exit without timeouts if app was terminated inside test', async () => {
    await device.launchApp({newInstance: true});
    await device.terminateApp();
  });

  it('should wait till app connects to Detox server', async () => {
    await device.launchApp();
    await element(by.text('Sanity')).tap();
    await device.launchApp({newInstance: true, launchArgs: {delayJsThreadBySeconds: '10'}});
    await element(by.text('Sanity')).tap();
  });
});
