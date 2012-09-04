$ = jQuery.sub()

class Index extends App.Controller
  events:
    'submit form':         'submit',
    'click .submit':       'submit',
    'click .cancel':       'cancel',

  constructor: (params) ->
    super

    # check authentication
    return if !@authenticate()

    # set title
    @title 'My Tickets'
    @fetch(params)
    @navupdate '#customer_tickets'

    @edit_form = undefined

    # lisen if view need to be rerendert
    Spine.bind 'ticket_create_rerender', (defaults) =>
      @log 'rerender', defaults
      @render(defaults)

  # get data / in case also ticket data for split
  fetch: (params) ->

    # use cache
    cache = App.Store.get( 'ticket_create_attributes' )

    if cache && !params.ticket_id && !params.article_id

      # get edit form attributes
      @edit_form = cache.edit_form

      # load user collection
      @loadCollection( type: 'User', data: cache.users )

      @render()
    else
      App.Com.ajax(
        id:    'ticket_create',
        type:  'GET',
        url:   '/ticket_create',
        data:  {
          ticket_id: params.ticket_id,
          article_id: params.article_id,
        },
        processData: true,
        success: (data, status, xhr) =>

          # cache request
          App.Store.write( 'ticket_create_attributes', data )

          # get edit form attributes
          @edit_form = data.edit_form

          # load user collection
          @loadCollection( type: 'User', data: data.users )

          # load ticket collection
          if data.ticket && data.articles
            @loadCollection( type: 'Ticket', data: [data.ticket] )

            # load article collections
            @loadCollection( type: 'TicketArticle', data: data.articles || [] )

            # render page
            t = App.Ticket.find(params.ticket_id).attributes()
            a = App.TicketArticle.find(params.article_id)
            
            # reset owner
            t.owner_id = 0
            t.customer_id_autocompletion = a.from
            t.subject = a.subject || t.title
            t.body = a.body
            @log '11111', t
          @render( options: t )
      )

  render: (template = {}) ->

    # set defaults
    defaults = template['options'] || {}
    if !( 'ticket_state_id' of defaults )
      defaults['ticket_state_id'] = App.TicketState.findByAttribute( 'name', 'new' )
    if !( 'ticket_priority_id' of defaults )
      defaults['ticket_priority_id'] = App.TicketPriority.findByAttribute( 'name', '2 normal' )

    # remember customers
    if $('#create_customer_id').val()
      defaults['customer_id'] = $('#create_customer_id').val()
      defaults['customer_id_autocompletion'] = $('#create_customer_id_autocompletion').val()
    else
#      defaults['customer_id'] = '2'
#      defaults['customer_id_autocompletion'] = '12312313'

    # generate form    
    configure_attributes = [
#      { name: 'customer_id',        display: 'Customer', tag: 'autocompletion', type: 'text', limit: 100, null: false, relation: 'User', class: 'span7', autocapitalize: false, help: 'Select the customer of the Ticket or create one.', link: '<a href="" class="customer_new">&raquo;</a>', callback: @userInfo },
      { name: 'group_id',           display: 'Group',    tag: 'select',   multiple: false, null: false, filter: @edit_form, nulloption: true, relation: 'Group', default: defaults['group_id'], class: 'span7',  },
#      { name: 'owner_id',           display: 'Owner',    tag: 'select',   multiple: false, null: true,  filter: @edit_form, nulloption: true, relation: 'User',  default: defaults['owner_id'], class: 'span7',  },
      { name: 'subject',            display: 'Subject',  tag: 'input',    type: 'text', limit: 100, null: false, default: defaults['subject'], class: 'span7', },
      { name: 'body',               display: 'Text',     tag: 'textarea', rows: 10,                  null: false, default: defaults['body'],    class: 'span7', },
#      { name: 'ticket_state_id',    display: 'State',    tag: 'select',   multiple: false, null: false, filter: @edit_form, relation: 'TicketState',    default: defaults['ticket_state_id'],    translate: true, class: 'medium' },
#      { name: 'ticket_priority_id', display: 'Priority', tag: 'select',   multiple: false, null: false, filter: @edit_form, relation: 'TicketPriority', default: defaults['ticket_priority_id'], translate: true, class: 'medium' },
    ]
    @html App.view('agent_ticket_create')(
      head: 'My Ticket',
      form: @formGen( model: { configure_attributes: configure_attributes, className: 'create' } ),
    )

    # add elastic to textarea
    @el.find('textarea').elastic()

    # update textarea size
    @el.find('textarea').trigger('change')

    # start customer info controller
    if defaults['customer_id']
      $('#create_customer_id').val( defaults['customer_id'] )
      $('#create_customer_id_autocompletion').val( defaults['customer_id_autocompletion'] )
      @userInfo( user_id: defaults['customer_id'] )

  cancel: ->
    @render()
    
  submit: (e) ->
    e.preventDefault()
        
    # get params
    params = @formParam(e.target)

    # fillup params
    if !params.title
      params.title = params.subject

    # create ticket
    object = new App.Ticket
    @log 'updateAttributes', params
    
    # find sender_id
    sender = App.TicketArticleSender.findByAttribute( 'name', 'Customer' )
    type   = App.TicketArticleType.findByAttribute( 'name', 'phone' )
    if params.group_id
      group  = App.Group.find(params.group_id)

    # create article
    params['article'] = {
      from:                     params.customer_id_autocompletion,
      to:                       (group && group.name) || '',
      subject:                  params.subject,
      body:                     params.body,
      ticket_article_type_id:   type.id,
      ticket_article_sender_id: sender.id,
      created_by_id:            params.customer_id,
    }
#          console.log('params', params)
    
    object.load(params)

    # validate form
    errors = object.validate()
    
    # show errors in form
    if errors
      @log 'error new', errors
      @validateForm( form: e.target, errors: errors )
      
    # save ticket, create article
    else 

      # disable form
      @formDisable(e)
      ui = @
      object.save(
        success: ->

          # notify UI
          ui.notify
            type:    'success',
            msg:     T('Ticket %s created!', @.number),
            link:    "#ticket/zoom/#{@.id}"
            timeout: 12000,
      
          # create new create screen
          ui.render()
          
          # scroll to top
          ui.scrollTo()

        error: ->
          ui.log 'save failed!'
          ui.formEnable(e)
      )

Config.Routes['customer_tickets'] = Index
