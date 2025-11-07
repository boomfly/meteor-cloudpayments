import crypto from 'crypto'
import {Meteor} from 'meteor/meteor'
import {Log} from 'meteor/logging'
import {WebApp} from 'meteor/webapp'
import {Random} from 'meteor/random'
import {fetch} from 'meteor/fetch'
import {_} from 'meteor/underscore'
import {URL, URLSearchParams} from 'url'

import {getConfig} from './config'
import {SIGNATURE_HEADER_NAME} from './constants'

import {CloudpaymentsClient} from './client'

_onPayCallback = null
_onCheckCallback = null
_onFailCallback = null
_onGetClientCallback = null

export Cloudpayments = {
  onPay: (cb) -> _onPayCallback = cb
  onCheck: (cb) -> _onCheckCallback = cb
  onFail: (cb) -> _onFailCallback = cb
  onGetClient: (cb) -> _onGetClientCallback = cb
}

defaultClient = new CloudpaymentsClient({
  publicId: getConfig().publicId
  secretKey: getConfig().secretKey
})

router = new WebApp.express.Router()

router.use('/', (req, res) ->
  Log.info({message: 'Cloudpayments.handler', method: req.method, headers: req.headers, url: req.url})
  method = req.method
  url = new URL(Meteor.absoluteUrl(req.url))
  query = Object.fromEntries(url.searchParams)

  response = (code, message) ->
    res.setHeader 'Content-Type', 'application/json'
    res.writeHead code
    res.end message

  if method not in ['POST', 'GET']
    Log.warn({message: 'Cloudpayments.handler: Unsupported method', method: req.method})
    return response 405

  if method is 'POST'
    chunks = []

    body = await new Promise (resolve, reject) ->
      req.on 'data', (chunk) ->
        chunks.push(chunk)
      req.on 'end', -> resolve Buffer.concat(chunks).toString('utf-8')
      req.on 'error', reject

    unless body
      Log.warn({message: 'Cloudpayments.handler: Empty POST body'})
      return response 400

    # console.log 'Cloudpayments.handler method', body

    payload = body
    if req.headers['content-type']?.indexOf('json') isnt -1
      params = JSON.parse(body)
    else
      params = Object.fromEntries(new URLSearchParams(body))
    
    merchantId = query.merchantId
  else
    url = new URL(Meteor.absoluteUrl(req.url))
    payload = url.searchParams.toString()
    {merchantId, ...restQuery} = query
    params = restQuery
    unless payload
      Log.warn({message: 'Cloudpayments.handler: Empty GET query'})
      return response 400

  # console.log 'Cloudpayments.handler', payload, params

  signatureHeader = req.headers[SIGNATURE_HEADER_NAME]

  unless signatureHeader
    Log.warn({message: 'Cloudpayments.handler: Request without signature', [SIGNATURE_HEADER_NAME]: signatureHeader})
    return response 401

  if merchantId and _onGetClientCallback
    client = await _onGetClientCallback(merchantId)
  else
    client = defaultClient

  signature = client._sign(payload)

  if signature isnt signatureHeader
    Log.warn({message: 'Cloudpayments.handler: Wrong request signature. Hack possible', signature, [SIGNATURE_HEADER_NAME]: signatureHeader})
    return response 401

  switch query.action
    when 'check'
      result = await _onCheckCallback?(params)
    when 'pay'
      result = await _onPayCallback?(params)
    when 'fail'
      result = await _onFailCallback?(params)
    else
      # Payment will be refunded
      result = {code: 0}

  unless result
    result = {code: 20}

  return response 200, JSON.stringify(result)
)

Meteor.startup ->
  WebApp.handlers.use '/api/cloudpayments', router
