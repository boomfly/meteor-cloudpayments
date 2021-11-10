import { Meteor } from 'meteor/meteor'
import { WebApp } from 'meteor/webapp'
import { Random } from 'meteor/random'
import { check, Match } from 'meteor/check'
import qs from 'qs'
import Url from 'url'

import Signature from './signature'
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

WebApp.rawConnectHandlers.use "/api/#{config.callbackScriptName}", (req, res, next) ->
  method = req.method
  query = Url.parse(req.url, true).query

  console.log 'Cloudpayments.handler method & action', method, query.action

  if method is 'POST'
    chunksLength = 0
    chunks = []

    body = await new Promise (resolve, reject) ->
      req.on 'data', (chunk) ->
        chunks.push(chunk)
        chunksLength += chunk.length
      req.on 'end', -> resolve Buffer.concat(chunks, chunksLength).toString('utf-8')
      req.on 'error', reject

    unless body
      console.warn 'Cloudpayments.handler: Empty POST body'
      res.writeHead 400
      res.end()
      return

    payload = body
    # console.log 'Cloudpayments.handler: POST payload', payload
    if typeof req.headers['content-type'] is 'string' and req.headers['content-type'].indexOf('json') isnt -1
      try
        params = JSON.parse(body)
      catch e
        console.log 'Cloudpayments.handler: JSON.parse error', e
        res.writeHead 400
        res.end()
        return
    else
      params = qs.parse payload
  else
    payload = Url.parse(req.url).query
    unless payload
      console.warn 'Cloudpayments.handler: Empty GET query'
      res.writeHead 400
      res.end()
      return
    params = Url.parse(req.url, true).query

  console.log 'Cloudpayments.handler: payload & params', payload, params

  signature = Signature.make payload, config.secretKey

  if signature isnt req.headers['content-hmac']
    console.warn 'Cloudpayments.handler: Wrong request signature. Hack possible', {signature, 'content-hmac': req.headers['content-hmac']}
    res.setHeader 'Content-Type', 'application/json'
    res.writeHead 401
    res.end()
    return

  switch query.action
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
  
  console.log 'Cloudpayments.handler: response', response

  res.setHeader 'Content-Type', 'application/json'
  res.writeHead response.statusCode or 200
  res.end JSON.stringify(response)
  