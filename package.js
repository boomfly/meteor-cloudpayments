Package.describe({
  // Short two-sentence summary
  summary: 'Meteor Cloudpayments integration',
  version: '0.3.0',
  name: 'boomfly:meteor-cloudpayments',
  git: 'https://github.com/boomfly/meteor-cloudpayments'
});

Package.onUse((api) => {
  // api.use('modules', 'server');
  api.use('webapp', 'server');
  api.use('underscore', 'server');
  api.use('ecmascript', 'server');
  api.use('coffeescript', 'server');

  api.mainModule('src/cloudpayments.coffee', 'server');
});
// This defines the tests for the package:
Package.onTest((api) => {
  // Sets up a dependency on this package.
  api.use('underscore', 'server');
  api.use('ecmascript', 'server');
  api.use('coffeescript', 'server');
  api.use('boomfly:meteor-cloudpayments');
  // Specify the source code for the package tests.
  api.addFiles('test/test.coffee', 'server');
});
