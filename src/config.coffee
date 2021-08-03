export default
  siteUrl: 'example.com'
  publicId: process.env.CLOUDPAYMENTS_PUBLIC_ID
  secretKey: process.env.CLOUDPAYMENTS_SECRET_KEY
  callbackScriptName: 'cloudpayments'
  callbackMethod: process.env.CLOUDPAYMENTS_CALLBACK_METHOD or 'post'
  currency: 'USD'
  language: 'RU'
  successUrl: null
