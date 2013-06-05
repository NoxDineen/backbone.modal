unless Backbone?
  throw new Error("Backbone is not defined. Please include the latest version from http://documentcloud.github.com/backbone/backbone.js")

class Backbone.Modal extends Backbone.View
  prefix: 'bb-modal'
  constructor: ->
    @args = Array::slice.apply(arguments)
    Backbone.View::constructor.apply(this, @args)

    @setUIElements()
    @delegateModalEvents()

  render: ->
    # use openAt or overwrite this with your own functionality
    data = @serializeData()

    @$el.addClass("#{@prefix}-wrapper")
    modalEl = $('<div />').addClass(@prefix)
    modalEl.html @template(data) if @template
    @$el.html modalEl

    # global events for key and click outside the modal
    $('body').on 'keyup', @checkKey
    $('body').on 'click', @clickOutside

    if @viewContainer
      @viewContainerEl = modalEl.find(@viewContainer)
      @viewContainerEl.addClass("#{@prefix}-views")
    else
      @viewContainerEl = modalEl

    @$el.show()
    @openAt(0) if @views?.length > 0
    @onRender?()

    modalEl.addClass('bb-modal-fadeIn')
    return this

  setUIElements: ->
    # get modal options
    @template       = @getOption('template')
    @views          = @getOption('views')
    @views?.length  = _.size(@views)
    @viewContainer  = @getOption('viewContainer')

    # hide modal
    @$el.hide()

    throw new Error('No template or views defined for Backbone.Modal') if _.isUndefined(@template) and _.isUndefined(@views)
    throw new Error('No viewContainer defined for Backbone.Modal') if @template and @views and _.isUndefined(@viewContainer)

  getOption: (option) ->
    # get class instance property
    return unless option
    if @options and option in @options and @options[option]?
      return @options[option]
    else
      return @[option]

  serializeData: ->
    # return the appropriate data for this view
    data = {}

    data = _.extend(data, @model.toJSON()) if @model
    data = _.extend(data, {items: @collection.toJSON()}) if @collection

    return data

  delegateModalEvents: ->
    @active = true

    # get elements
    cancelEl = @getOption('cancelEl')
    submitEl = @getOption('submitEl')

    # set event handlers for submit and cancel
    if submitEl
      @$el.on 'click', submitEl, @triggerSubmit

    if cancelEl
      @$el.on 'click', cancelEl, @triggerCancel

    # set event handlers for views
    for key of @views
      unless key is 'length'
        match     = key.match(/^(\S+)\s*(.*)$/)
        trigger   = match[1]
        selector  = match[2]

        @$el.on trigger, selector, @views[key], @triggerView

  undelegateModalEvents: ->
    @active = false

    # get elements
    cancelEl = @getOption('cancelEl')
    submitEl = @getOption('submitEl')

    # set event handlers for submit and cancel
    if submitEl
      @$el.off 'click', submitEl, @triggerSubmit

    if cancelEl
      @$el.off 'click', cancelEl, @triggerCancel

    # set event handlers for views
    for key of @views
      unless key is 'length'
        match     = key.match(/^(\S+)\s*(.*)$/)
        trigger   = match[1]
        selector  = match[2]

        @$el.off trigger, selector, @views[key], @triggerView

  checkKey: (e) =>
    if @active
      switch e.keyCode
        when 27 then @triggerCancel(null, true)
        when 13 then @triggerSubmit(null, true)

  clickOutside: (e) =>
    @triggerCancel(null, true) if $(e.target).hasClass("#{@prefix}-wrapper") and @active

  buildView: (viewType) ->
    # returns a Backbone.View instance, a function or an object
    return unless viewType
    if _.isFunction(viewType)
      view = new viewType(@args[0])

      if view instanceof Backbone.View
        return {el: view.render().$el, view: view}
      else
        return {el: viewType(@args[0])}

    return {view: viewType, el: viewType.$el}

  triggerView: (e) =>
    # trigger what view should be rendered
    e?.preventDefault?()
    options       = e.data
    instance      = @buildView(options.view)
    @currentView  = instance.view || instance.el

    if options.onActive
      if _.isFunction(options.onActive)
        options.onActive(this)
      else if _.isString(options.onActive)
        this[options.onActive].call(this, options)

    if @shouldAnimate
      @animateToView(instance.el)
    else
      @shouldAnimate = true
      @$(@viewContainerEl).html instance.el

  animateToView: (view) ->
    tester = $('<tester/>')
    tester.html @$el.clone().css(top: -9999, left: -9999)
    if $('tester').length isnt 0 then $('tester').replaceWith tester else $('body').append tester

    if @viewContainer
      container     = tester.find(@viewContainer)
    else
      container     = tester

    container.removeAttr("style")

    previousHeight  = container.outerHeight()
    container.html(view)
    newHeight       = container.outerHeight()

    if previousHeight is newHeight
      @$(@viewContainerEl).html view
    else
      @$(@viewContainerEl).css(opacity: 0)

      @$(@viewContainerEl).animate {height: newHeight}, 100, =>
        @$(@viewContainerEl).css(opacity: 1)
        @$(@viewContainerEl).html view

  triggerSubmit: (e, keyEvent) =>
    # triggers submit
    e?.preventDefault()

    if @beforeSubmit
      return if @beforeSubmit() is false

    @submit?()

    @trigger('modal:close') if keyEvent
    @close()

  triggerCancel: (e, keyEvent) =>
    # triggers cancel
    e?.preventDefault()

    if @beforeCancel
      return if @beforeCancel() is false

    @cancel?()

    @trigger('modal:close') if keyEvent
    @close()

  close: ->
    # closes view
    $('body').off 'keyup', @checkKey
    $('body').off 'click', @clickOutside
    @currentView?.remove?()
    @shouldAnimate = false
    @remove()

  openAt: (index) ->
    # loop through views and trigger the index
    i = 0
    for key of @views
      unless key is 'length'
        view = @views[key] if i is index
        i++

    if view
      @currentIndex = index
      @triggerView(data: view)

    return this

  next: ->
    @openAt(@currentIndex+1) if @currentIndex+1 < @views.length-1

  previous: ->
    @openAt(@currentIndex-1) if @currentIndex-1 < @views.length-1
