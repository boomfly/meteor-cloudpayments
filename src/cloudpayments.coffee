import { Meteor } from 'meteor/meteor'
import { Random } from 'meteor/random'
import { check, Match } from 'meteor/check'
import { HTTP } from 'meteor/http'

import PGSignature from './signature'
import config from './config'
import CloudpaymentsApi from './api'

export {CloudpaymentsApi}

# api = new CloudpaymentsApi config

# console.log 'cloudpayments', api.getNotificaiton('pay')

export default class Cloudpayments
  @config: (cfg) ->
    if cfg then _.extend(config, cfg) else _.extend({}, config)
    @_api = new CloudpaymentsApi config
  @onPay: (cb) -> @_onPay = cb
  @onCheck: (cb) -> @_onCheck = cb
  @onFail: (cb) -> @_onFail = cb

  @createOrder: (params, cb) ->
    _.extend params, {
      CultureName: config.language
      Currency: params.Currency or config.currency
    }

    if config.successUrl
      params.SuccessRedirectUrl = config.successUrl
      params.FailRedirectUrl = config.successUrl

    @_api.createOrder params

# Маршруты для обработки REST запросов от Cloudpayments

Rest = new Restivus
  useDefaultAuth: true
  prettyJson: true

Meteor.startup ->
  Rest.addRoute config.callbackScriptName, {authRequired: false},
    "#{config.callbackMethod}": ->
      if config.debug
        console.log 'Cloudpayments.restRoute', @queryParams, @bodyParams

      if @queryParams?.TransactionId?
        params = _.omit @queryParams, ['__proto__']
      else if @bodyParams?.TransactionId?
        params = _.omit @bodyParams, ['__proto__']
      else
        params = {}

      # payload = JSON.stringify(params)
      # signature = PGSignature.make payload, config.secretKey
      # console.log signature, payload, @request.headers, @request.body

      # if pg_sig isnt params.pg_sig
      #   console.log 'Cloudpayments.restRoute invalid signature', pg_sig
      #   return
      #     statusCode: 403
      #     body: 'Access restricted 403'

      switch @queryParams.action
        when 'check'
          response = Cloudpayments._onCheck?(params)
        when 'pay'
          response = Cloudpayments._onPay?(params)
        when 'fail'
          response = Cloudpayments._onFail?(params)
        else
          # Payment will be refunded
          response = {code: 0}

      unless response
        response = {code: 20}

      if config.debug
        console.log 'Cloudpayments.restRoute.response', response

      response

# WebApp.connectHandlers.use "/api/#{config.callbackScriptName}", (req, res, next) ->
#   method = req.method

#   if method is 'POST'
#     chunksLength = 0
#     chunks = []
#     body = await new Promise (resolve, reject) ->
#       req.on 'data', (chunk) ->
#         chunks.push(chunk)
#         chunksLength += chunk.length
#       req.on 'end', -> resolve Buffer.concat(chunks, chunksLength).toString('utf-8')
#       req.on 'error', reject