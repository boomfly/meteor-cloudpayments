import {HTTP} from 'meteor/http'

###*
Class Cloudpayments API client
###
class CloudpaymentsApi
  ###*
  Constructor
  @param {object} config
  ###
  constructor: (config) ->
    {publicId, secretKey} = config
    @_publicId = publicId
    @_secretKey = secretKey
    @_apiUrl = 'https://api.cloudpayments.ru/'

  request: (url, params) ->
    params = params or {}
    response = HTTP.post "#{@_apiUrl}/#{url}", {
      data: params
      auth: "#{@_publicId}:#{@_secretKey}"
    }
    response.data

  test: -> @request 'test'

  ###*
  @typedef CreateOrderParams
  @type {object}
  @property {number} Amount - Сумма платежа
  @property {string} [Currency] - Валюта RUB/USD/EUR/GBP (см. справочник). Если параметр не передан, то по умолчанию принимает значение RUB
  @property {string} Description - Назначение платежа в свободной форме
  @property {string} [Email] - E-mail плательщика
  @property {boolean} [RequireConfirmation] - Есть значение true — платеж будет выполнен по двухстадийной схеме
  @property {boolean} [SendEmail] -	Если значение true — плательщик получит письмо со ссылкой на оплату
  @property {string} [InvoiceId] - Номер заказа в вашей системе
  @property {string} [AccountId] - Идентификатор пользователя в вашей системе
  @property {string} [OfferUri] - Ссылка на оферту, которая будет показываться на странице заказа
  @property {string} [Phone] - Номер телефона плательщика в произвольном формате
  @property {boolean} [SendSms] - Если значение true — плательщик получит СМС со ссылкой на оплату
  @property {boolean} [SendViber] - Если значение true — плательщик получит сообщение в Viber со ссылкой на оплату
  @property {string} [CultureName] - Язык уведомлений. Возможные значения: "ru-RU", "en-US". ([см. справочник]{@link https://developers.cloudpayments.ru/#lokalizatsiya})
  @property {string} [SubscriptionBehavior] - Для создания платежа с подпиской. Возможные значения: CreateWeekly, CreateMonthly
  @property {string} [SuccessRedirectUrl]	- Адрес страницы для редиректа при успешной оплате
  @property {string} [FailRedirectUrl] - Адрес страницы для редиректа при неуспешной оплате
  @property {object} [JsonData] - Любые другие данные, которые будут связаны с транзакцией, в том числе инструкции для формирования [онлайн-чека]{@link https://developers.cloudpayments.ru/#format-peredachi-dannyh-dlya-onlayn-cheka}
  ###

  ###*
  @typedef CreateOrderResponse
  @type {object}
  @property {boolean} Success
  @property {CreateOrderResponseModel} Model
  ###

  ###*
  @typedef CreateOrderResponseModel
  @type {object}
  @property {number} Number
  @property {number} Amount
  @property {string} Currency
  @property {number} CurrencyCode
  @property {string} Email
  @property {string} Description
  @property {boolean} RequireConfirmation
  @property {string} Url
  ###

  ###*
  @summary Создание счета для отправки по почте
  @desc Метод формирования ссылки на оплату и последующей отправки уведомления на e-mail адрес плательщика.
  @param {CreateOrderParams} params
  @example <caption>Пример запроса</caption>
  # var api = new CloudpaymentsApi(config);
  # var order = api.createOrder({
  #   Amount: 10.0,
  #   Currency: "RUB",
  #   Description: "Оплата на сайте example.com",
  #   Email: "client@test.local",
  #   RequireConfirmation: true,
  #   SendEmail: false
  # });
  @example <caption>Пример ответа</caption>
  # {
  #   "Model":{
  #     "Id":"f2K8LV6reGE9WBFn",
  #     "Number":61,
  #     "Amount":10.0,
  #     "Currency":"RUB",
  #     "CurrencyCode":0,
  #     "Email":"client@test.local",
  #     "Description":"Оплата на сайте example.com",
  #     "RequireConfirmation":true,
  #     "Url":"https://orders.cloudpayments.ru/d/f2K8LV6reGE9WBFn",
  #   },
  #   "Success":true,
  # }
  @returns {CreateOrderResponse}
  ###
  createOrder: (params) -> @request 'orders/create', params

  ###*
  @summary Просмотр настроек уведомлений
  @desc Метод просмотра настроек уведомлений с указанием типа уведомления.
  @param {string} type
  @example <caption>Пример ответа</caption>
  {
    "Model": {
      "IsEnabled": true,
      "Address": "http://example.com",
      "HttpMethod": "GET",
      "Encoding": "UTF8",
      "Format": "CloudPayments"
    },
    "Success": true,
    "Message": null
  }
  ###
  getNotificaiton: (type) -> @request "site/notifications/#{type}/get"

  ###*
  @summary Изменение настроек уведомлений
  @desc Метод изменения настроек уведомлений.
  @param {string} type
  @param {object} params
  @example <caption>Пример запроса</caption>
  {
    "IsEnabled": true,
    "Address": "http://example.com",
    "HttpMethod": "GET",
    "Encoding": "UTF8",
    "Format": "CloudPayments"
  }
  @example <caption>Пример ответа</caption>
  {
    "Model": {
      "IsEnabled": true,
      "Address": "http://example.com",
      "HttpMethod": "GET",
      "Encoding": "UTF8",
      "Format": "CloudPayments"
    },
    "Success": true,
    "Message": null
  }
  ###
  updateNotificaiton: (type, params) -> @request "site/notifications/#{type}/update", params


export default CloudpaymentsApi