import {PACKAGE_NAME} from './constants'

Meteor.settings.public[PACKAGE_NAME] = {
  
}

Meteor.settings.private = {} unless Meteor.settings.private
Meteor.settings.private[PACKAGE_NAME] = {
  siteUrl: process.env.CLOUDPAYMENTS_SITE_URL or Meteor.absoluteUrl()
  publicId: process.env.CLOUDPAYMENTS_PUBLIC_ID
  secretKey: process.env.CLOUDPAYMENTS_SECRET_KEY
  callbackPathname: process.env.CLOUDPAYMENTS_CALLBACK_PATHNAME or 'cloudpayments'
  callbackMethod: process.env.CLOUDPAYMENTS_CALLBACK_METHOD or 'POST'
  currency: process.env.CLOUDPAYMENTS_CURRENCY or 'USD'
  language: process.env.CLOUDPAYMENTS_LANGUAGE or 'RU'
}

export getConfig = -> Meteor.settings.private[PACKAGE_NAME]