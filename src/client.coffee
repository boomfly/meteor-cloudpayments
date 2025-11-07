import {fetch} from 'meteor/fetch'
import crypto from 'crypto'

BASE_URL = 'https://api.tiptoppay.kz'

export class CloudpaymentsClient
  constructor: (config) ->
    @_baseUrl = config.baseUrl or BASE_URL
    @_publicId = config.publicId
    @_secretKey = config.secretKey

  test: () -> await @_request 'test', {}

  # Orders
  createOrder: (params) -> await @_request 'orders/create', params

  # Payments
  payWithToken: (params) -> await @_request 'payments/tokens/charge', params
  refund: (params) -> await @_request 'payments/refund', params
  cancel: (params) -> await @_request 'payments/void', params

  # Notifications
  getNotification: (type) -> await @_request "site/notifications/#{type}/get"

  # Private methods

  _request: (pathname, params, method = 'POST') ->
    options = {
      method
      headers: {
        'Content-Type': 'application/json;charset=utf-8'
        'Authorization': 'Basic ' + Buffer.from("#{@_publicId}:#{@_secretKey}").toString('base64')
      }
    }
    url = new URL("#{@_baseUrl}/#{pathname}")
    if method.toUpperCase() is 'GET'
      url.search = new URLSearchParams(params).toString()
    else
      options.body = JSON.stringify(params) if params
    response = await fetch url, options
    # console.log 'Cloudpayments.request', response, response.headers, options
    if response.status isnt 200
      return response
    await response.json()

  _sign: (message) -> crypto.createHmac('sha256', @_secretKey).update(message).digest('base64')
