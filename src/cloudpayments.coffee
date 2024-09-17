import crypto from 'crypto'
import {Meteor} from 'meteor/meteor'
import {WebApp} from 'meteor/webapp'
import {Random} from 'meteor/random'
import {fetch} from 'meteor/fetch'
import {_} from 'meteor/underscore'
import {URL, URLSearchParams} from 'url'

import {getConfig} from './config'
import {SIGNATURE_HEADER_NAME} from './constants'

class Cloudpayments
  constructor: ->
    config = getConfig()
    # Маршруты для обработки REST запросов от Cloudpayments Callback
    pathname = "/api/#{config.callbackPathname}"
    @_registerHandler pathname

  config: (cfg) ->
    config = getConfig()
    return config unless cfg
    handlerUpdated = false
    if cfg.callbackPathname and config.callbackPathname isnt cfg.callbackPathname
      pathname = "/api/#{cfg.callbackPathname}"
      @_registerHandler pathname
      handlerUpdated = true
    Object.assign(config, cfg)

  onPay: (cb) -> @_onPay = cb
  onCheck: (cb) -> @_onCheck = cb
  onFail: (cb) -> @_onFail = cb

  # Orders
  createOrder: (params) -> await @_request 'orders/create', params

  # Payments
  payWithToken: (params) -> await @_request 'payments/tokens/charge', params
  refund: (params) -> await @_request 'payments/refund', params
  cancel: (params) -> await @_request 'payments/void', params

  # Notifications
  getNotification: (type) -> await @_request "site/notifications/#{type}/get"
  updateNotification: (type, params) -> await @_request "site/notifications/#{type}/update", params

  # You must update Check notifications manually
  updateNotifications: (pathname) ->
    config = @config()
    pathname = "/api/#{config.callbackPathname}" unless pathname
    url = "#{config.siteUrl}#{pathname}"
    
    makeUrl = (type) -> "#{url}?action=#{type}"

    promises = ['check', 'pay', 'fail'].map (type) =>
      typeUrl = makeUrl type
      notification = await @getNotification type
      if notification.status is 401
        console.error 'Cloudpayments::updateNotifications wrong secret key', type
        return await Promise.resolve()
      # console.log 'Cloudpayments.updateNotifications notification', type, notification, typeUrl
      updateResult = null
      if notification.Model.Address isnt typeUrl
        updateResult = await @updateNotification type, {
          IsEnabled: true
          Address: typeUrl
          HttpMethod: config.callbackMethod?.toUpperCase() or 'POST'
        }
        # console.log 'Cloudpayments.updateNotifications updateResult', type, updateResult
        if not updateResult.Success
          console.error 'Cloudpayments::updateNotifications url mismatch please change it manually', type, updateResult
      # await Promise.resolve()
      updateResult

    result = await Promise.all promises

    # console.log 'Cloudpayments.updateNotifications result', result
    
    return

  # Private methods

  _request: (pathname, params, method = 'POST') ->
    {isTest, publicId, secretKey} = getConfig()
    apiUrl = 'https://api.tiptoppay.kz'
    options = {
      method
      headers: {
        'Content-Type': 'application/json;charset=utf-8'
        'Authorization': 'Basic ' + Buffer.from("#{publicId}:#{secretKey}").toString('base64')
      }
    }
    url = new URL("#{apiUrl}/#{pathname}")
    if method.toUpperCase() is 'GET'
      url.search = new URLSearchParams(params).toString()
    else
      options.body = JSON.stringify(params) if params
    response = await fetch url, options
    # console.log 'Cloudpayments.request', response, response.headers, options
    if response.status isnt 200
      return response
    await response.json()

  _sign: (message, secret) -> crypto.createHmac('sha256', secret).update(message).digest('base64')

  _registerHandler: (pathname, shouldUpdateWebhook = true) ->
    config = @config()
    handlerIndex = WebApp.rawConnectHandlers.stack.findIndex (i) => i.handler is @_handler
    if handlerIndex > 0
      WebApp.rawConnectHandlers.stack.splice handlerIndex, 1
    WebApp.rawConnectHandlers.use pathname, @_handler

  # Webhooks handler
  _handler: (req, res, next) =>
    config = @config()
    method = req.method
    url = new URL(Meteor.absoluteUrl(req.url))
    query = Object.fromEntries(url.searchParams)

    response = (code, message) ->
      res.setHeader 'Content-Type', 'application/json'
      res.writeHead code
      res.end message

    console.log 'Cloudpayments.handler method', method, req.headers, req.url

    if method is 'POST'
      chunksLength = 0
      chunks = []

      body = await new Promise (resolve, reject) ->
        req.on 'data', (chunk) ->
          # console.log 'Cloudpayments.handler POST data chunk', chunk
          chunks.push(chunk)
          chunksLength += chunk.length
        req.on 'end', -> resolve Buffer.concat(chunks, chunksLength).toString('utf-8')
        req.on 'error', reject

      unless body
        console.warn 'Cloudpayments.handler: Empty POST body'
        return response 400

      console.log 'Cloudpayments.handler method', body

      payload = body
      if req.headers['content-type']?.indexOf('json') isnt -1
        params = JSON.parse(body)
      else
        params = Object.fromEntries(new URLSearchParams(body))
    else
      url = new URL(Meteor.absoluteUrl(req.url))
      payload = url.searchParams.toString()
      params = query
      unless payload
        console.warn 'Cloudpayments.handler: Empty GET query'
        return response 400

    console.log 'Cloudpayments.handler', payload, params

    signatureHeader = req.headers[SIGNATURE_HEADER_NAME]

    unless signatureHeader
      console.warn 'Cloudpayments.handler: Request without signature', {[SIGNATURE_HEADER_NAME]: signatureHeader}
      return response 401

    # signature = @_sign payload, @_signatureSecret
    signature = @_sign payload, config.secretKey

    # TODO: signature generation algo

    if signature isnt signatureHeader
      console.warn 'Cloudpayments.handler: Wrong request signature. Hack possible', {
        signature
        [SIGNATURE_HEADER_NAME]: signatureHeader
      }
      return response 401

    switch query.action
      when 'check'
        result = await @_onCheck?(params)
      when 'pay'
        result = await @_onPay?(params)
      when 'fail'
        result = await @_onFail?(params)
      else
        # Payment will be refunded
        result = {code: 0}

    unless result
      result = {code: 20}

    console.log 'Cloudpayments.handler result', result

    return response 200, JSON.stringify(result)

export default Cloudpayments = new Cloudpayments
