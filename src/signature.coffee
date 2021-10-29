import { URL } from 'url'
import path from 'path'
import crypto from 'crypto'
import {sprintf} from 'sprintf-js'

export default class Signature
  @make: (message, secret) ->
    crypto.createHmac('sha256', secret).update(message).digest('base64')
